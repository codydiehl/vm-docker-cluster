#!/bin/bash

##############################################
# Author: Cody.Diehl
# Email: diehl17c@gmail.com
# Desc: Create a 4-6 Node docker swarm using 
#  a single virtual machine image as a base 
#  and VirtualBox to achieve copy-on-write 
#  & greatly reduce space necessary.
##############################################


# dont seperate VM's with spaces in there name into two variables 
IFS=$'\n'

# get default VM path for VirtualBox
VMPATH="/$(VBoxManage list systemproperties | grep folder | cut -d/ -f2-)/"

# declare an array to store the VM names
declare -a VMS
VMS=( $(ls -1 "/$(VBoxManage list systemproperties | grep folder | cut -d/ -f2-)/") )

# Get user choice of VM from the Array
PS3='Please enter choice for VM to Clone: '
select opt in "${VMS[@]}"
do
echo $opt
break
done

# build our clone command
echo
VM=$(echo "/$(VBoxManage list systemproperties | grep folder | cut -d/ -f2-)/$opt")
VDI_FILE=$(find "${VM}" -name "*.vdi" -o -name "*.vmdk" -o -name "*.vhd" | grep -v Snapshot)

echo $VDI_FILE
if [ -z $VDI_FILE ]; then
  echo "This VM does not have a valid VDI, VMDK, or VHD file"
else
  # continue

  echo "Creating VM Clone"
  VBoxManage clonehd "$VDI_FILE" ~/cluster_base.vdi
  ls -lh ~/cluster_base.vdi

  sleep 1
  # Generate OS name and type from Original VM
  echo
  echo "VM Name will be ostype-mgr-01, ostype-wrk-01, etc."
  OSTYPE=$(VBoxManage showvminfo $opt|grep OS:|cut -d: -f2-|sed 's/ \{1,\}//g'|sed 's/(/_/g'|sed 's/-bit)//g')
  OSNAME=$(echo $OSTYPE | sed 's/_64//g' | tr '[:upper:]' '[:lower:]')

  MGRNAME=$(echo $OSNAME-mgr-0)
  WRKNAME=$(echo $OSNAME-wrk-0)

  # determine size to determine cluster names 
  echo "How Large Of a Cluster Do You Want? 4-6"
  read NUM

  # define num of workers/managers based on total size
  declare -a NAME
  if [ $NUM -eq 4 ]; then
    NAME[0]="$MGRNAME"1
    NAME[1]="$WRKNAME"1
    NAME[2]="$WRKNAME"2
    NAME[3]="$WRKNAME"3
  elif [ $NUM -eq 5 ]; then
    NAME[0]="$MGRNAME"1
    NAME[1]="$MGRNAME"2
    NAME[2]="$MGRNAME"3
    NAME[3]="$WRKNAME"1
    NAME[4]="$WRKNAME"2
  elif [ $NUM -eq 6 ]; then
    NAME[0]="$MGRNAME"1
    NAME[1]="$MGRNAME"2
    NAME[2]="$MGRNAME"3
    NAME[3]="$WRKNAME"1
    NAME[4]="$WRKNAME"2
    NAME[5]="$WRKNAME"3
  fi

  # output the names based on cluster size
  echo
  echo "The Cluster will have the following names"
  echo ${NAME[*]}

  sleep 1

  # confirm memory amount
  echo
  echo "How much memory do you want per VM in megabytes?"
  read MEM

  sleep 1


  # Get user confirmation to proceed
  read -p "Do you want to proceed with the Build? (y/n) " -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]; then # answer was yes
    #continue build

    # create first manager node VM
    echo
    VBoxManage createvm --name ${NAME[0]} --ostype "$OSTYPE" --register
    VBoxManage storagectl ${NAME[0]} --name "sata1" --add sata
    VBoxManage storageattach ${NAME[0]} --storagectl "sata1" --port 0 --device 0 --type hdd --medium ~/cluster_base.vdi --mtype multiattach
    VBoxManage modifyvm ${NAME[0]} --memory $MEM
    VBoxManage modifyvm ${NAME[0]} --nic1 nat --natpf1 "guestssh,tcp,,2230,,22"
    VBoxManage modifyvm ${NAME[0]} --nic2 hostonly --hostonlyadapter1 "vboxnet0"
    
    # create all the remaining node VMs
    x=1
    while [ $x -lt $NUM ]; do
      echo
      echo
      VBoxManage createvm --name ${NAME[$x]} --ostype $OSTYPE --register
      VBoxManage storagectl ${NAME[$x]} --name "sata1" --add sata
      VBoxManage storageattach ${NAME[$x]} --storagectl "sata1" --port 0 --device 0 --type hdd --medium cluster_base.vdi --mtype multiattach
      VBoxManage modifyvm ${NAME[$x]} --memory $MEM
      VBoxManage modifyvm ${NAME[$x]} --nic1 nat --natpf1 "guestssh,tcp,,223$x,,22"
      VBoxManage modifyvm ${NAME[$x]} --nic2 hostonly --hostonlyadapter1 "vboxnet0"
      x=$(($x+1))
      sleep 2
    done

    echo "Confirmation of new cluster size"
    # confirm new cluster size
    /usr/bin/du -h -d1 "$VMPATH" | grep "$OSNAME"
    /usr/bin/du -h ~/cluster_base.vdi


  elif [[ ! $REPLY =~ ^[Yy]$ ]]; then # answer was no or any other reply
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
    # handle exit from shell or function but dont exit interactive shell
  fi
fi
