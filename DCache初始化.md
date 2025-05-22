# 初始化客户端

DCacheClientSDK使用协程连接服务端，在协程环境不可用时，将自动切换为同步接口。我们使用DCacheSDK，通常将其设置为全局单例。如下所示：

```cpp
//推荐这种初始化方式
class DCacheOpt: public taf::TC_Singleton<DCacheOpt>
{c
public:
    void init( const CommunicatorPtr &_comm ){
        TC_Config tConf;
        tConf.parseFile( ServerConfig::BasePath + ServerConfig::ServerName + ".conf" );
        string module_name = tConf.get( "/main/dcache/bizname/<module_name>" );
        string proxy_name = tConf.get( "/main/dcache/bizname/<proxy_name>" );
        client.init(_comm,proxy_name,module_name);
        //可以设置超时时间，第一个为同步超时时间，第二个为异步超时时间，为0则为默认超时时间,taf_v3有效
        //client.init(_comm,proxy_name,module_name,timeout);
    }
    DCacheAPI_N<string> &getClient(){
        return client;
    }
public:
    DCacheAPI_N<string> client;//模版类型为key
};

//这种声明方式也是可以的，注意如果有两个DCacheAPI_N key同为long的话就比较危险了。因为实际上他们是同个单例实例！
typedef taf::TC_Singleton<DCacheAPI_N<long>> DCacheAPI_Singleton;

//使用方法：在Server::initialize() 添加如下初始化代码
DCacheOpt::getInstance()->init(Application::getCommunicator());


//其他地方这样调用
DCacheOpt::getInstance()->getClient().API(args...)


```

### 使用DCacheCenter

初始化：

```cpp
TC_Config tConf;
tConf.parseFile( ServerConfig::BasePath + ServerConfig::ServerName + ".conf" );
string module_name = tConf.get( "/main/dcache/bizname/<module_name>" );
string proxy_name = tConf.get( "/main/dcache/bizname/<proxy_name>" );
DCacheCenter<std::string, HUYA::TestJceStruct> _dcache;
int timeout = 3000;
_dcache.init(comm, proxy_name, module_name, timeout);

//get
HUYA::TestJceStruct value;
std::string key = "key";
_dcache.get(key, value);

```

# 二期模块kv模式(使用IgnoreUKey)

在使用二期模块时，如果希望每个主键下只有一条数据，就像kv一样，不去理会ukey使用的时候，可以使用setIgnoreUKey()。使用方法：

```cpp
    //在client初始化时调用setIgnoreUKey
    client.init(_comm,proxy_name,module_name,timeout);
    client.setIgnoreUKey("ukey_nouseage");

    //在调用了setIgnoreUKey("ukey_nouseage");之后 调用DCache接口时就当做没有ukey字段去使用就可以了 such as:
    DBuilder builder;
    builder.set(Hash::value=2341); //只用设置value字段，不管ukey
    DCacheOpt::getInstance()->getClient().insert("242354",builder.updateValues,{});

```

# 使用DCache\_Struct和DBuilder

在许多DCache API中，比如updateAtom，在填入参数的时候常常会需要写入map\<string, UpdateValue>和vector\<Condition>等类型，这些类型的构造会对用户使用时带来一定程度困扰，所以我们引入了DCache\_Struct和DBuilder来方便用户使用DCache API.\
使用方法：

```cpp
    //DCache_Struct是一个宏，它会创建以第一个参数为名称的命名空间
    //创建名称为Hash的命名空间，timestamp、count、xxx为uk和value字段
    DCache_Struct(Hash,timestamp,count,xxx)
    //创建名称为Rank的命名空间，uid、sex、age为uk和value字段
    DCache_Struct(Rank,uid,sex,age)
    
    //使用：
    DBuilder builder;
    //设置map<string, UpdateValue>
    builder.set(Hash::xxx="abcde").set(Hash::count="1");
    //设置vector<Condition>
    builder.add(Hash::timestamp=="1234567");
    
    DCacheOpt::getInstance()->getClient().updateAtom(key,builder.updateValues,builder.vConds);

```

**DCache\_Struct里面的字段可以包括mk, uk, value的字段**
