
# TAF服务

----------------------------------------

标题：使用bash生成TAF框架新/初始服务代码  
描述：使用命令生成TAF框架服务代码
LANGUAGE：Bash  
CODE：  
```bash
<Usage:  /usr/local/taf/create_taf_server.sh  App  Server  Servant>
比如创建一个HUYA应用下面的客户资料服务
/usr/local/taf/create_taf_server.sh  HUYA  CustomProfileServer  UserProfie
```

----------------------------------------

标题：TAF框架服务目录结构
描述：CustomProfileServer资料服务展示TAF服务的基础目录结构，其：1.makfile中的TARGET是该服务名称（Servername）；2. UserPrfofile.jce是该服务协议，里面包含了接口定义；3. CustomProfileImp.cpp 对应接口的实现入口
代码：  
LANGUAGE: Bash
CODE:
```
➜  CustomProfileServer tree
.
├── CustomProfile.jce
├── CustomProfileImp.cpp
├── CustomProfileImp.h
├── CustomProfileServer.cpp
├── CustomProfileServer.h
└── makefile
```

----------------------------------------

标题：TAF服务定义客户资料服务的JCE接口协议
描述：该JCE协议指定了服务所属模块名HUYA，服务Servant是CustomProfile(实际使用的时候是CustomProfileServant)，然后接口是getCustomInfo，最后获取客户资料的请求结构GetCustomProfileReq和响应结构GetCustomProfileRsp。该服务协议CustomProfile.jce，生成CustomProfile.h，供其他业务include使用

LANGUAGE: JCE
CODE:  
```TAF  CustomProfile.jce
module HUYA {

// 获取客户资料接口协议
struct GetCustomInfoReq {  
    0 optional string uid;  // 客户id  
}  

// 返回客户资料
struct GetCustomInfoRsp {  
    0 optional string name; // 客户名称  
}  

interface CustomProfile {  
    // 获取客户资料
    int getCustomInfo(GetCustomInfoReq req, out GetCustomInfoRsp rsp);  
}  
```

----------------------------------------

标题：TAF服务RPC调用
描述：TAF服务调用其他服务接口例子，从客户服务获取客户资料（服务：CustomProfileServer，接口是getCustomInfo） 
LANGUAGE: C++  
CODE:  
```TAF  
第一步：修改makefile引入接口、请求和回包结构体定义

DEPEND_STRUCT += HUYA.GetCustomInfoReq GetCustomInfoRsp
DEPEND_INTERFACE += HUYA.CustomProfileServant.getCustomInfo

第二步：一般在***Server.cpp文件中initialize方法对客户服务进行调用初始化
1. ***Server.h 增加引入头文件和声明客户服务指针变量
#include "CustomProfile.h" 
HUYA::CustomProfileServantPrx m_customProfilePrx;

2. ***Server.cpp 对客户服服务指针做初始化、
m_customProfilePrx = Application::getCommunicator()->stringToProxy<HUYA::CustomProfileServantPrx>("HUYA.CustomProfileServer.CustomProfileServantObj");

第三步：逻辑调用
HUYA::GetCustomInfoReq reqCustomInfo;
customReq.uid = "7758258";
HUYA::GetCustomInfoRsp rspCustomInfo;
iRet = g_app.::m_customProfilePrx->getCustomInfo(reqCustomInfo, rspCustomInfo);

```

----------------------------------------

标题：TAF服务输出远程日志到文件porfile
描述：FDLOG远程日志宏，指定了远程日志文件profile，将请求的字段uid和回包里面的name字段输出到日志里面，采用竖线分割；
LANGUAGE: C++  
CODE:  
```TAF  
FDLOG("custom") << req.uid << "|" << rsp.name << "|" << std::endl;
```

----------------------------------------






