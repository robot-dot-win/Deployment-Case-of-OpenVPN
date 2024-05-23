# 引言

[OpenVPN](https://github.com/OpenVPN)以其健壮性、安全性、通用性、扩展性，可适用于企业级VPN网络解决方案。本《OpenVPN企业级应用部署案例》针对一个资源集中式机房的企业级应用场景，从需求描述到方案设计、部署实施，尽量给出一个模板级的解决案例。

# 场景

- 用户是一个为全球客户提供IT开发和服务的企业，在全国各地和部分境外地区设有分支机构。
- 全部员工总规模2500人。60%以上的员工需在客户现场工作，接入客户的内网，访问客户内部IT系统（可能通过客户的堡垒机）和外部Internet资源（可能通过客户的代理服务器）。
- 公司总部是一幢办公楼，建有一个中心机房，有80台左右的物理服务器，使用QEMU进行虚拟化管理。
- 总部网络结构非常简单：从电信运营商租用足够带宽的Internet专线和若干固定IP地址；路由器+企业防火墙+核心交换机+汇聚交换机+接入交换机；核心交换机上划分三类VLAN（服务器VLAN、设备管理VLAN、员工VLAN）；所有VLAN都可通过NAT方式访问外网；服务器通过路由器上的端口映射对外提供必要的服务。
- 总部中心机房的服务器集中承担应用系统（FI/HR/OA/PM/CRM/WEB/GIT/SVN等）、研发/测试/演示环境。
- 邮件系统是租用的商业运营的企业邮箱，有SMTPS服务。
- 无企业目录服务器(AD/LDAP)；有统一认证中心(CAS)，通过SMTPS进行用户认证，为应用系统提供单点登录(SSO)服务。
- 公司IT管理活动通过ISO/IEC 27001体系认证。

# 需求

- 分支机构、客户现场、出差途中的员工，应该能够如同在总部办公楼一样，随时安全、方便地访问中心机房的服务器（这些服务器非必要情况下不通过端口映射对外开放服务）。
- 应该支持各类客户端（Windows/Linux/macOS/Android/iOS）的接入。
- 有时候，客户会要求将项目服务器物理放置在客户工作现场，此时不在现场的项目成员也应该能访问该服务器。
- 员工在客户现场工作时，接入的是客户的网络；有的客户还提供VPN服务，允许非现场人员远程接入客户网络。但是对于不提供VPN服务的客户网络，员工也应该能远程接入。
- 所有通过Internet线路对服务器的访问，必须符合AAA(Authentication/Authorization/Accounting)安全模式（ISO/IEC 27001要求的）。
- 对服务器的访问无流量敏感活动、无高并发活动，满足普通WEB应用即可。
- 无关键业务应用。某部分失效后在1小时内启用相应的后备系统即可。

# 方案

- OpenVPN支持几乎所有平台，SSL/TLS加密传输，可允许员工的各种设备在各种场合安全地接入总部网络。
- 在总部机房以服务器模式部署OpenVPN服务器，IP4网络，掩码20位，IP地址容量4k，满足员工可同时接入的设备规模。
- 核心交换机上设置服务器VLAN与OpenVPN网络之间的路由转发，OpenVPN服务器上设置服务器VLAN与OpenVPN的路由转发，可允许接入OpenVPN的设备如同在总部本地一样访问服务器。
- OpenVPN可通过插件或Shell脚本灵活扩展用户认证方式。这里通过Linux PAM插件的形式，以SMTPS通过邮件系统进行认证。接入OpenVPN的`Common Name`使用邮箱地址域名之前的小写用户名，每个`Common Name`绑定一个固定IP地址，这样即可确定每位接入者的身份。
- OpenVPN的0-11级日志，可根据网络安全审计要求选择所需级别。
- 由于客户端所在网络情况复杂多样，在许多网络环境中，UDP协议是被阻止的，因此选用TCP协议。
- 允许OpenVPN客户端之间的网络连通，这样，当一个客户端是服务器时，其他客户端可以访问它；尤其是，当这个客户端设置了代理服务时，其他客户端可通过该代理服务器访问远端网络。
- OpenVPN客户端连接的时候，获得推送的到服务器VLAN的静态路由，这样，客户端即可如同在总部本地一样访问服务器。为了简化配置，应该精心选择服务器VLAN网段和OpenVPN网段，尽可能避免与客户端所在网络地址发生冲突。
- 客户端所在的许多网络都使用自己当地的DNS以便访问Intranet资源，因此OpenVPN服务器不应该向客户端推送DNS，也不能将客户端原来的流量导向VPN隧道，以免影响客户端原来的正常工作环境。
- 在总部内网使用自己的DNS服务器，将OpenVPN服务器的域名解析到内网IP地址，以便从内网也可以连接OpenVPN，以访问远端其他OpenVPN客户端。
- 由于两个原因，不启用网络传输压缩：启用压缩导致安全性降低；通过OpenVPN主要访问服务器的各种应用系统，而应用系统通常已配置了网络传输压缩。

# 实施

## 1、网络

- 服务器网段：`192.168.248.0/21` 划分成8个24位掩码VLAN
- OpenVPN网段：`192.168.224.0/20`
- OpenVPN服务器IP地址：`192.168.255.254` 服务端口：`81` 域名：`vpn.foo.com`
- 核心交换机静态路由：`192.168.224.0/20` via `192.168.255.254`
- 公网DNS解析：`vpn.foo.com` --> `公网IP1,公网IP2,公网IP3`
- 内网DNS解析：`vpn.foo.com` --> `192.168.255.254`
- 路由器端口映射：`公网IP1,公网IP2,公网IP3:81` --> `192.168.255.254:81`

## 2、操作系统

### 2.1 安装

选用CentOS Stream 9，极小化安装。

### 2.2 防火墙

禁用SELinux，以nftables替代firewalld：
```bash
[root@localhost ~]# systemctl disable --now selinux-autorelabel-mark
[root@localhost ~]# grubby --update-kernel ALL --args selinux=0
[root@localhost ~]# reboot
[root@localhost ~]# dnf remove setroubleshoot-server
[root@localhost ~]# systemctl disable --now firewalld
[root@localhost ~]# dnf remove firewalld
[root@localhost ~]# dnf install nftables
[root@localhost ~]# if a
```
编辑本仓库的`nftables.conf`文件，以`192.168.255.254`地址的网卡名替换文件中的`eth0`，然后替换`/etc/sysconfig/nftables.conf`文件。

启动nftables服务：
```bash
[root@localhost ~]# systemctl enable --now nftables
```

### 2.3 内核参数

由于OpenVPN服务器需要处理较高的网络并发连接，并且需要启用路由转发，所以需要优化和调整内核参数。本仓库附带了两个适用于8G内存的配置文件：
- `z1-common.conf`      一般Linux服务器内核参数
- `z2-openvpn.conf`     OpenVPN服务器内核参数

将这个两个文件放在`/etc/sysctl.d/`下面，然后重启服务器使之生效。

## 3、安装

OpenVPN程序和关联模块在[EPEL扩展包](https://docs.fedoraproject.org/en-US/epel/)中，可参照说明安装EPEL。

然后安装OpenVPN：
```bash
[root@localhost ~]# dnf install openvpn
```

## 4、配置

### 4.1 调整服务启动参数

主要考虑三个因素：
- 为符合IT管理规范对日志的要求，应删掉 --suppress-timestamps 参数，使日志内容带有时间戳；
- 因为超过了1k个同时连接数，所以需调整最大sockets连接数参数；
- 必要时增加ExecStartPre、ExecStartPost等参数，以执行前置、后置等服务。

```bash
[root@localhost ~]# systemctl edit openvpn-server@.service
```
输入如下内容然后保存：
```
[Service]
ExecStart=
ExecStart=/usr/sbin/openvpn --cipher AES-256-GCM --data-ciphers AES-256-GCM:AES-256-CBC --config %i.conf
LimitNOFILE=4096
```

### 4.2 生成证书

使用[easy-rsa](https://github.com/OpenVPN/easy-rsa)方便操作。这项工作也可以在其他已安装easy-rsa的机器上进行（例如一台Windows机器）。

以CentOS Stream 9为例，easy-rsa也在EPEL扩展包中，需按前述先安装EPEL。然后安装easy-rsa：
```bash
[root@localhost ~]# dnf install easy-rsa
```
如果该easy-rsa是初次使用，则需先创建PKI和CA：
```bash
[root@localhost ~]# cd /usr/share/easy-rsa/3
[root@localhost 3]# ./easyrsa init-pki
[root@localhost 3]# ./easyrsa build-ca nopass
```
CA证书：
```
./pki/ca.crt
```
生成OpenVPN服务器证书:
```bash
[root@localhost 3]# ./easyrsa build-server-full foo-vpnserver nopass
```
OpenVPN服务器证书和私钥文件：
```
./pki/issued/foo-vpnserver.crt
./pki/private/foo-vpnserver.key
```
生成Diffie Hellman参数：
```bash
[root@localhost 3]# ./easyrsa gen-dh
```
参数文件：
```
./pki/dh.pem
```

将上面生成的4个文件复制到OpenVPN服务器的配置文件目录中：`/etc/openvpn/server/`

在OpenVPN服务器上，生成TLS共享密钥：
```bash
[root@localhost ~]# openvpn --genkey secret /etc/openvpn/server/foo-ta.key
```

### 4.3 配置PAM认证

从这里下载pam_smtp模块源程序：https://github.com/robot-dot-win/pam_smtp

从这里下载pam_usermatch模块源程序：https://github.com/robot-dot-win/pam_usermatch

编译：
```bash
[root@localhost ~]# dnf install gcc gcc-c++ pam-devel libcurl-devel
[root@localhost ~]# g++ pam_smtp.cpp -o pam_smtp.so -shared -lpam -lcurl -fPIC
[root@localhost ~]# g++ pam_usermatch.cpp -o pam_usermatch.so -shared -lpam -fPIC
```
将模块程序`pam_smtp.so`和`pam_usermatch.so`复制到`/usr/lib64/security/`下面。

根据实际情况，检查修改本仓库的`openvpn.pam`配置文件，将其放到`/etc/pam.d/`下面。

### 4.4 确定OpenVPN服务器配置文件

根据实际情况，检查修改本仓库的`tun0.conf`及相关配置文件，将它们放到`/etc/openvpn/server/`下面。

## 5、运行

```bash
[root@localhost ~]# mkdir /var/log/openvpn
[root@localhost ~]# chmod 755 /etc/openvpn/server/*.sh
[root@localhost ~]# systemctl enable --now openvpn-server@tun0
```

## 6、客户端

本仓库文件`openvpn-foo.ovpn`是适用于所有平台的客户端配置文件，需根据实际情况进行修改。

常用平台的OpenVPN客户端软件下载：
- Windows: https://build.openvpn.net/downloads/releases/
- Linux:   https://community.openvpn.net/openvpn/wiki/OpenvpnSoftwareRepos
- macOS:   https://github.com/Tunnelblick/Tunnelblick
- Android: https://github.com/schwabe/ics-openvpn
- iOS:     境外苹果应用商店搜索`OpenVPN Connect`

安装完后只需要导入客户端配置文件即可。不再赘述。

# 扩展

此处仅结合当前应用场景说明几点可以扩展的地方。

- 限流：如果需对用户做网络流量限制，可以结合核心交换机和OpenVPN服务器nftables二者的策略来完成。
- 访问控制：对于特定用户和特定资源的访问控制，可以动态设置核心交换机/OpenVPN服务器nftables的ACL数据库。
- 境外访问：当境外分支机构和出差用户较多的时候，为保证可访问性、网络速度和稳定性，可租用AWS/阿里/百度/腾讯等在新加坡/北美的VPS做代理服务器，成本低廉。

# 许可

1. 本仓库所有内容是免费的、公开的、不限商用的，允许转载、摘录/引用，但必须遵守如下限制：
- 转载限制：必须注明原著作权人版权和原文出处，必须公开、免费发布，不允许以任何方式收费阅读（除非获得原著作权人书面授权）。
- 摘录/引用限制：必须在参考文献中列出原文出处，所形成的新作品版权归新作品著作权人所有，但其任何非纸质版本不允许以任何方式收费阅读（除非获得原著作权人书面授权）。

2. 使用本仓库的任何内容，必须遵循[《GNU通用公共许可协议》](https://www.gnu.org/licenses/)第三版的第15、16、17条之规定。
