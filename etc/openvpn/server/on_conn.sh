#!/bin/bash
#
# OpenVPN服务器发生客户端连接时执行的脚本，2024-05-20
#
# 版权所有：Copyright (C) 2024, Martin Young <martin_young@live.cn>
#
# 测试环境：CentOS Stream 9，OpenVPN V2.5.4-V2.6.10
#-----------------------------------------------------------------------------

# 1、常用功能举例：根据ACL策略动态调整nftables数据集

# 2、判断客户端是否从总部内网连接；如果不是，则需将服务器网段路由推送给客户端：
if [ -n "${1}" ]; then
    ip=(`echo $trusted_ip | /usr/bin/awk -F '[.]' '{ print $1,$2 }'`)
    if [ ${ip[0]} -eq 192 -a ${ip[1]} -eq 168 ]; then
        local="yes"
    elif [ ${ip[0]} -eq 172 -a ${ip[1]} -ge 16 -a ${ip[1]} -le 31 ]; then
        local="yes"
    elif [ ${ip[0]} -eq 10 ]; then
        local="yes"
    else
        echo 'push "route 192.168.248.0 255.255.248.0"' > "${1}"
    fi
fi

exit 0
