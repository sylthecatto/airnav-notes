### Proxmox installation and Setup
1. Installed proxmox ve 9.2 iso from https://www.proxmox.com/en/downloads/proxmox-virtual-environment/iso

	Blocker: "found ISO9660 FS but no, or wrong proxmox cd-id, skipping"
	
	Solution: The iso was first moved to ventoy drive, did not work. I tried flashing it on a separtate drive using balenaetcher, did not work when installing either graphical or terminal. I used dd to flash it manually.

```bash
sudo dd if=/home/aw16/Downloads/proxmox-ve_9.2-1.iso of=/dev/sdb bs=4M status=progress conv=fsync

```
2. Set up proxmox install

	bootdisk fs: ext4
	bootdisk: /dev/sda
	timezone: Europe/Vienna
	keyboard layout: us
	admin email: aaronoliverio@protonmail.com
	hostname: pve.hans.training
	host ip: 192.168.100.2/24
	gateway: 192.168.100.1
	dns: 192.168.100.1

3. Make the airnav laptop access the proxmox virtual environment on 192.168.100.2

	Solution: At first I used a small switch, but it was the property of the NIS team, so I opted to use the FCO department's router and used it only as a layer 2 device.



### First week

