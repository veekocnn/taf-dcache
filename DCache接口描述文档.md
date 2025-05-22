## <h1> DCache接口描述文档 </h1>


* [初始化DCacheAPI_N](#initClient)
    * [设置ukey](#ignore_uk)
    * [初始化DCacheLRUClient](#lru_client)
    * [理解lru算法](#lru_principle)
* [初始化DCacheCenter](#initDCacheCenter)
* [返回值与含义](#retCode)
* [SelectResult类型](#SelectResult)
* [k-k-row,list,set,zset通用](#getmainkeycount)
  * [读](#getmainkeycount)
    * [getMainKeyCount](#getmainkeycount)
    * [getMainKeyCountBatch](#getmainkeycountbatch)
    * [getMKAllMainKey](#getallmainkey)
  * [写](#del)
    * [del](#del)
    * [delBatch](#delbatch)
    * [erase](#erase)
* [k-k-row](#kkv-select)
  * [读](#kkv-select)
    * [select](#kkv-select)
    * [selectBatch](#kkv-selectBatch)
    * [selectBatchOr](#kkv-selectBatchOr)
    * [scanMK](#kkv-scanmk)
    * [scanMKFromDB](#kkv-scanmkfromdb)
  * [写](#kkv-insert)
    * [insert](#kkv-insert)
    * [insertBatch](#kkv-insertbatch)
    * [refreshExpiretime](#refreshexpiretime)
    * [updateOrInsertNotAtom](#kkv-update)
    * [updateAtom](#kkv-updateatom)
    * [updateAtomFetch](#kkv-updateatomfetch)
    * [updateAtomFetch_v2](#kkv-updateatomfetch_v2)
    * [updateFetchBatch](#kkv-updatefetchbatch)
    * [callFunction(Discard)](#kkv-callFunction)
    * [callFunctionWithVer](#kkv-callFunctionWithVer)
    * [callFunctionBatch](#kkv-callFunctionBatch)
* [list](#list-getlist)
  * [读](#list-getlist)
    * [getList](#list-getlist)
    * [getRangeList](#list-getrangelist)
  * [写](#list-pushlist)
    * [pushList](#list-pushlist)
    * [popList](#list-poplist)
    * [replaceList](#list-replacelist)
    * [trimList](#list-trimlist)
    * [remList](#list-remlist)
* [set](#set-getset)
  * [读](#set-getset)
    * [getSet](#set-getset)
    * [isInSet](#set-isinset)
  * [写](#set-addSet)
    * [addSet](#set-addset)
    * [delSet](#set-delset)
* [zset](#zset-getscore)
  * [ZSet隐藏字段](#zset-field)
  * [读](#zset-getscore)
    * [getScoreZSet](#zset-getscore)
    * [getRankZSet](#zset-getrank)
    * [getRankAndScoreZSet](#zset-getrankandscore)
    * [getRankAndScoreZSetBatch](#zset-getrankandscoreBatch)
    * [getRangeZSet](#zset-getrange)
    * [getRangeZSetBatch](#zset-getrangebatch)
    * [getRangeZSetByScore](#zset-getrangebyscore)
    * [getRangeZSetByScoreBatch](#zset-selectbatch)
  * [写](#zset-addzset)
    * [addZSet](#zset-addzset)
    * [incScoreZSet](#zset-incscore)
    * [incScoreZSetEx](#zset-incscoreex)
    * [delZSet](#zset-del)
    * [delRangeZSet](#zset-delrange)
    * [updateZSet](#zset-update)
* [key-value@DCacheAPI_N.h 推荐使用](#kv-get-API-N)
    * [读](#kv-get-API-N)
        * [get](#kv-get-API-N)
        * [getBatch](#kv-getbatch-API-N)
    * [写](#kv-set-API-N)
        * [setString](#kv-set-API-N)
        * [setBatch](#kv-setbatch-API-N)
        * [delString](#kv-del-API-N) 
        * [updateStringEx](#kv-update-API-N)


* [key-value@DCacheCenter.h 逐渐废弃](#kv-get)
  * [读](#kv-get)
    * [get](#kv-get)
    * [getBatch](#kv-getbatch)
    * [Scan](#kv-scan)
  * [写](#kv-erase)
    * [erase](#kv-erase)
    * [set](#kv-set)
    * [setBatch](#kv-setbatch)
    * [modify](#kv-modify)
    * [drop](#kv-drop)
    * [dropBatch](#kv-dropbatch)
    * [updateStringEx](#kv-update)
 

# 初始化客户端 <a id="initClient"></a>
DCacheClientSDK使用协程连接服务端，在协程环境不可用时，将自动切换为同步接口。我们使用DCacheSDK，通常将其设置为全局单例。如下所示：
```c++
//推荐这种初始化方式
class DCacheOpt: public taf::TC_Singleton<DCacheOpt>
{c
public:
    void init( const CommunicatorPtr &_comm ){
        TC_Config tConf;
        tConf.parseFile( ServerConfig::BasePath + ServerConfig::ServerName + ".conf" );
        string module_name = tConf.get( "/main/dcache/bizname/<module_name>" );
        string proxy_name = tConf.get( "/main/dcache/bizname/<proxy_name>" );
        client.init(_comm,proxy_name,module_name);
        //可以设置超时时间，第一个为同步超时时间，第二个为异步超时时间，为0则为默认超时时间,taf_v3有效
        //client.init(_comm,proxy_name,module_name,timeout);
    }
    DCacheAPI_N<string> &getClient(){
        return client;
    }
public:
    DCacheAPI_N<string> client;//模版类型为key
};

//这种声明方式也是可以的，注意如果有两个DCacheAPI_N key同为long的话就比较危险了。因为实际上他们是同个单例实例！
typedef taf::TC_Singleton<DCacheAPI_N<long>> DCacheAPI_Singleton;

//使用方法：在Server::initialize() 添加如下初始化代码
DCacheOpt::getInstance()->init(Application::getCommunicator());


//其他地方这样调用
DCacheOpt::getInstance()->getClient().API(args...)

```
### 使用DCacheCenter <a id="initDCacheCenter"></a>
初始化：
```c++
TC_Config tConf;
tConf.parseFile( ServerConfig::BasePath + ServerConfig::ServerName + ".conf" );
string module_name = tConf.get( "/main/dcache/bizname/<module_name>" );
string proxy_name = tConf.get( "/main/dcache/bizname/<proxy_name>" );
DCacheCenter<std::string, HUYA::TestJceStruct> _dcache;
int timeout = 3000;
_dcache.init(comm, proxy_name, module_name, timeout);

//get
HUYA::TestJceStruct value;
std::string key = "key";
_dcache.get(key, value);
```

# <a id="ignore_uk"></a>二期模块kv模式(使用IgnoreUKey)
在使用二期模块时，如果希望每个主键下只有一条数据，就像kv一样，不去理会ukey使用的时候，可以使用setIgnoreUKey()。使用方法：
```
    //在client初始化时调用setIgnoreUKey
    client.init(_comm,proxy_name,module_name,timeout);
    client.setIgnoreUKey("ukey_nouseage");

    //在调用了setIgnoreUKey("ukey_nouseage");之后 调用DCache接口时就当做没有ukey字段去使用就可以了 such as:
    DBuilder builder;
    builder.set(Hash::value=2341); //只用设置value字段，不管ukey
    DCacheOpt::getInstance()->getClient().insert("242354",builder.updateValues,{});
```


# <a id="dcache_struct"></a> 使用DCache_Struct和DBuilder
在许多DCache API中，比如updateAtom，在填入参数的时候常常会需要写入map<string, UpdateValue>和vector<Condition>等类型，这些类型的构造会对用户使用时带来一定程度困扰，所以我们引入了DCache_Struct和DBuilder来方便用户使用DCache API.\
使用方法：
```c++
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
**DCache_Struct里面的字段可以包括mk, uk, value的字段**

# <a id="lru_client"></a>初始化带LRU的客户端
我们为一期KV，二期KKV实现了LRU客户端缓存，在Key有明显热点集中的大QPS访问情形中，应该使用LRU技术来降低延迟以及提高QPS，同时减轻了DCache压力。
使用LRU缓存也非常简单，只需要更换模版即可:
请注意，需要在配置文件中，添加如下配置：


```
<main>
<lru>
    # 本Lru实例会缓存1000*100个key，超过则启用淘汰，每个key 5秒后即超时
  	lruSize=1000
  	expireTime=5
  	hashNum=100
</lru>
<TokenBucket>
    # 放入LRU 前，先看看此KEY 是否‘过热’
    # 即在brustCap=5(令牌桶最大只能容纳5个令牌),bucketRate=5(每秒放回去5个令牌)
    # 则DCacheClient 在该key突发请求速率为 5次/s，平均请求速率为 5次/s以内，不会走LRU逻辑，否则放入LRU缓存
  	lruSize=1000
  	bucketCap=5
  	bucketRate=5
  	hashNum=100
</TokenBucket>
</main>
```

在使用一期DCacheCenterWithLRU时，需要手动初始化Lru代码（兼容性考虑），调用`initLRUConfig`即可（必须增加上文配置项，否则assert）。

```
TC_Config tConf;
tConf.parseFile( ServerConfig::BasePath + ServerConfig::ServerName + ".conf" );
string module_name = tConf.get( "/main/dcache/bizname/<module_name>" );
string proxy_name = tConf.get( "/main/dcache/bizname/<proxy_name>" );
DCacheCenter<std::string, HUYA::TestJceStruct> _dcache;
int timeout = 3000;
_dcache.init(comm, proxy_name, module_name, timeout);

//需要手动调用下这个接口
_dcache.initLRUConfig();
//下面的不用了
<!--{-->
<!--    int lruSize = taf::TC_Common::strto<int>( conf.get( "/main/lru/<lruSize>", "0" ) );-->
<!--    int expireTime = taf::TC_Common::strto<int>( conf.get( "/main/lru/<expireTime>", "0" ) );-->
<!--    int hashNum = taf::TC_Common::strto<int>( conf.get( "/main/lru/<hashNum>", "0" ) );-->
<!--    LOG->debug() << "init lru config,lruSize:" << lruSize << ",expireTime:" << expireTime << ",hashNum:" << hashNum << endl;-->
    
<!--    assert( lruSize != 0 );-->
<!--    assert( hashNum != 0 );-->
<!--    //CacheWithHash 不可用运行时调用，线程不安全-->
<!--    //Cache 可以随便调用，线程安全-->
<!--    _dcache.initLRU( lruSize, expireTime, hashNum );-->
<!--}-->
<!--{-->
<!--    int lruSize = taf::TC_Common::strto<int>( conf.get( "/main/TokenBucket/<lruSize>", "0" ) );-->
<!--    int bucketCap = taf::TC_Common::strto<int>( conf.get( "/main/TokenBucket/<bucketCap>", "0" ) );-->
<!--    int bucketRate = taf::TC_Common::strto<int>( conf.get( "/main/TokenBucket/<bucketRate>", "0" ) );-->
<!--    int hashNum = taf::TC_Common::strto<int>( conf.get( "/main/TokenBucket/<hashNum>", "0" ) );-->
<!--    LOG->debug() << "init bucketToken config,lruSize:" << lruSize-->
<!--                 << ",bucketCap:" << bucketCap << ",bucketRate:"-->
<!--                 << bucketRate << ",hashNum:" << hashNum << endl;-->
<!--    _dcache.initBucket( lruSize, bucketCap, bucketRate, hashNum );-->
<!--}-->

        
//get
HUYA::TestJceStruct value;
std::string key = "key";
_dcache.get(key, value);


```

在使用二期DCacheAPIWithLRU_N时，`LRU KKV `初始化代码(必须增加上文配置项，否则assert):
```c++
class DCacheOpt: public taf::TC_Singleton<DCacheOpt>
{
public:
    void init( const CommunicatorPtr &_comm ){
        TC_Config tConf;
        tConf.parseFile( ServerConfig::BasePath + ServerConfig::ServerName + ".conf" );
        string module_name = tConf.get( "/main/dcache/bizname/<module_name>" );
        string proxy_name = tConf.get( "/main/dcache/bizname/<proxy_name>" );
        client.init(_comm,proxy_name,module_name);
        //DCacheAPIWithLRU_N构造函数已调用initLRUConfig，下面代码不用了
        //client.initLRU(100,5,10);
        //client.initBucket(100,10,2,10);
    }
    DCacheAPIWithLRU_N<string> &getClient(){
        return client;
    }
public:
    DCacheAPIWithLRU_N<string> client;// 这是LRU版本
};
```

### <a id="lru_principle"></a> 理解LRU 与令牌桶
我们使用LRU实现客户端缓存，在数据集中突发访问场景，可以有效降低延迟，提高QPS，但对于海量数据（keys）以及有限的客户端内存限制下，我们应该首先判断KEY是否应该进入LRU缓存，对此，使用令牌桶来测试该key的速率：
[令牌桶原理](https://henix.github.io/feeds/weixin.sogou.zhoudaobiji/2016-09-10-1000000002.html)。\
在DCacheClient配置文件中，有几个重要配置项`bucketCap`,`bucketRate`:

放入LRU 前，先看看此KEY 是否‘过热’，即是否在brustCap=5(令牌桶最大只能容纳5个令牌),bucketRate=5(每秒放回去5个令牌)条件内，则DCacheClient 在该key突发请求速率为 5次/s，平均请求速率为 5次/s以内，不会走LRU逻辑，否则放入LRU缓存.





# <a id="retCode"></a>现有返回值，以及含义：

返回值字符串 | 含义|返回数值
------------------ |------------------ | ----------------
ET_TAF_ERROR_JCE_DECODEERR |对应taf异常：JCESERVERDECODEERR -1 | -1001
ET_TAF_ERROR_JCE_ENCODEERR |对应taf异常：JCESERVERENCODEERR -2 | -1002
ET_TAF_ERROR_JCE_NOFUNCERR |对应taf异常：JCESERVERNOFUNCERR -3 | -1003
ET_TAF_ERROR_JCE_NOSERVANTERR |对应taf异常：JCESERVERNOSERVANTERR -4 | -1004
ET_TAF_ERROR_JCE_RESETGRID |对应taf异常：JCESERVERRESETGRID -5 | -1005
ET_TAF_ERROR_JCE_QUEUETIMEOUT |对应taf异常：JCESERVERQUEUETIMEOUT -6 | -1006
ET_TAF_ERROR_JCE_ASYNCCALLTIMEOUT |对应taf异常：JCEASYNCCALLTIMEOUT -7 | -1007
ET_TAF_ERROR_JCE_PROXYCONNECTERR |对应taf异常：JCEPROXYCONNECTERR -8 | -1008
ET_TAF_ERROR_JCE_OVERLOAD |对应taf异常：JCESERVEROVERLOAD -9 | -1009
ET_TAF_ERROR_JCE_ADAPTERNULL |对应taf异常：JCEADAPTERNULL -10 | -1010
ET_TAF_ERROR_JCE_UNKNOWNERR |对应taf异常：JCESERVERUNKNOWNERR -99 | -1099
 ET_UUID_DUPLICATED | 该请求为重试请求(uuid已存在) 不会重复更新数据 | -41
 ET_EXCEED_LIMIT | 输入参数超过限制错误 | -38
 ET_ERASE_DIRTY_ERR	| 不允许使用该接口删除脏数据 | -35
 ET_PARAM_LIMIT_VALUE_ERR | 条件集合的某个元素的limit属性值填写错误 | -34
 ET_PARAM_UPDATE_UKEY_ERR | 更新字段包含了联合字段 | -33
 ET_PARAM_OP_ERR	| op错误，只支持SET | -31
 ET_PARAM_NOT_EXIST | 字段不存在 | -30
 ET_PARAM_DIGITAL_ERR | 字段错误，例如值为数字类型的字段包含了非数字字符 | -29
 ET_PARAM_TOO_LONG | 字段大小超过限制 | -28
 ET_PARAM_MISSING | 待写入数据未包含全部联合字段 | -27
 ET_PARAM_REDUNDANT	| 字段重复 | -26
 ET_CACHE_ERR | 缓存错误 | -25
 ET_DB_ERR | 数据库读取错误 | -24
 ET_READ_ONLY |cache只读，一般是在主备切换过程中产生|-23
 ET_DATA_TOO_MUCH | 数据量过大 | -22
 ET_MEM_FULL | 内存满 | -21
 ET_PARTIAL_FAIL | 表示部分数据insert失败 | -16
 ET_DATA_VER_MISMATCH | 版本不一致 | -15
 ET_INPUT_PARAM_ERROR | 参数错误，例如key为空 | -12
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_DATA_EXIST | 数据已存在，禁止insert | -10
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_NO_DATA | 数据不存在 | -6
 ET_KEY_AREA_ERR | 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR | 系统异常 | -1
 ET_SUCC | 读取数据成功 | 0
 更新的行数| getMainKeyCount/select/updateOrInsertNotAtom| >=0
 更新的行数| updateAtom/updateAtomFetch/remList成功 | >=0
 
 # <a id="SelectResult"></a> SelectResult类型
 ```C++
 
 /**
    * select返回的结果集，底层实际上是vector<map<string,string>>
    * 通常的用法是通过size()获取总记录数，然后循环通过[]操作符取出每一条记录
    * 再通过SelectRecord::get取出每条记录中所需要的字段值
*/
    
    class SelectResultBase
    {
    public:
        // 获取原始的数据结构
        vector<map<string, string>> &data()
        {
            return _vtResult;
        }
        // 获取结果集中的的记录数
        size_t size()
        {
            return _vtResult.size();
        }
        // 获取主索引下总的记录数，只有在调用select接口时设置bRetTotal为true时才有意义
        size_t &totalRecords()
        {
            return _iTotalRecords;
        }
        //获取查询结果
        int &getReturnValue()
        {
            return _ret;
        }
        string &getMainKey()
        {
            return _mainKey;
        }
        // 清空结果集
        void clear()
        {
            _vtResult.clear();
        }
        static uint8_t CastVersion( const string &strVer )
        {
            uint8_t ver_uint8 = *reinterpret_cast<const uint8_t *>( strVer.c_str() );
            return ver_uint8;
        }
        static int CastVersionPrint( const string &strVer )
        {
            int ver_print = ( int )CastVersion( strVer ) - ( int )0; //just for print
            return ver_print;
        }
        // 获取一条记录
        map<string, string> &operator[]( size_t i ) throw( DCacheClientException )
        {
            if( i >= _vtResult.size() )
            {
                throw DCacheClientException( "index " + TC_Common::tostr( i ) + " overflow!" );
            }
            
            return _vtResult[i];
        }
        
    private:
        vector<map<string, string>> _vtResult;
        
        size_t _iTotalRecords; // 主索引下总的记录数
        
        int _ret;

        string _mainKey;
    };

  class SelectResult : public SelectResultBase
    {
    public:
        SelectResult() {}
        
        SelectResult( const SelectResultBase &resultBase ): SelectResultBase( resultBase ) {}
        /**
        * 获取原始的数据结构
        * @return, vector<map<string, string>>，所有字段值都以string保存，需要自己进行数据类型的转换
        */
        vector<map<string, string> > &data();
        /**
        * 获取回返结果集中记录数
        * @return size_t, 记录条数
        */
        size_t size();
        /**
        * 获取主索引下总的记录数
        * @return size_t, 记录条数
        */
        size_t totalRecords();
        
        /**
        * 清空结果集
        */
        void clear();
        /**
        * 获取一条记录，指定的索引下标超出范围时注意捕获DCacheClientException异常
        * @param i, 记录索引
        * @return SelectRecord结构
        */
        SelectRecord operator[]( size_t i ) throw( DCacheClientException );
    };
 ```
 [↑返回标题↑](#header)

# <a id="getmainkeycount"></a> getMainKeyCount
```C++
int getMainKeyCount( const K &sMainIndex, bool bCheckExpire = false )
```
**功能：** 获取主键下数据记录总数，\
**详细说明：** 在KKV中，将返回Ukey个数，在zset/list/set中，将返回mainkey下的元素个数。\
**时间复杂度：** O(1)\
**参数：**  
```
sMainIndex 主键
bCheckExpire 为false时获取的数据记录总数会包含已过期的数据，设为true可过滤已过期的数据，复杂度由O(1)->O(N)
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 其他值(大于等于0)|主键下的记录总数 | ≥0
 [↑返回标题↑](#header)

 

# <a id="getmainkeycountbatch"></a> getMainKeyCountBatch
```C++
template<typename KK>
int getMainKeyCountBatch( const vector<KK> &vtMainKey, map<KK, int> &keyCount, bool bCheckExpire = false )
```
**功能：** 获取多个主键下数据记录总数\
**时间复杂度：** O(n)，n为元素个数\
**参数：**  
```
vtMainKey 主键
keyCount 返回每个key对应的记录个数
bCheckExpire 为false时获取的数据记录总数会包含已过期的数据，设为true可过滤已过期的数据，复杂度由O(1)->O(N)
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 批量读取成功 | 0 
 [↑返回标题↑](#header)
 
 
 
# <a id="getallmainkey"></a> getMKAllMainKey
```C++
int getMKAllMainKey( int index, int count, vector<string> &mainKey, bool &isEnd )
```
**功能：** 获取cache下所有主键\
**参数：**  
```
index 开始获取的hash桶编号
count 获取多少个hash桶数据
mainKey 返回的结果，主键
isEnd 是否还有数据（是否还有更多的桶，如果有，应该继续遍历，添加游标）
```
**用法：**
```
// 我们需要分批获取数据，并且建议每批数量不超过1万
    while(!isEnd){
        std::vector<string> tmp;
        DCacheOpt::getInstance()->getClient().getMKAllMainKey(index,5000,tmp,isEnd);
        index +=5000;
        for(auto&id:tmp){
            cout << id <<endl;
        }
    }
```  
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_INPUT_PARAM_ERROR | 参数错误，例如mainKey为空 | -12
 ET_MODULE_NAME_INVALID	| 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC	| 删除成功 | 0
 [↑返回标题↑](#header)



# <a id="del"></a> del
```C++
int del( const K &sMainIndex, const vector<DCache::Condition> &vtConds )
```
**功能：** 删除数据，注意：del接口将同时删除缓存与数据库中的数据，而erase接口则只是删除缓存中的数据\
**参数：**  
```
sMainIndex 主键
vtConds 条件集合,支持==/!=/</>/<=/>=
```
**用法：**
```
//condition 支持符号重载：
auto condition = {Rank::uid>100000,Rank::sex==1,Rank::age>18,Rank::age>=18,Rank::age<=18,Rank::age<18,Rank::age!=18};

auto condition = {Rank::uid>100000,Rank::sex==1,Rank::age!=18};
DCacheOpt::getInstance()->getClient().del(“mk”,condition);

```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_LIMIT_VALUE_ERR | 条件集合的某个元素的limit属性值填写错误 | -34
 ET_PARAM_NOT_EXIST | 字段不存在 | -30
 ET_PARAM_REDUNDANT	| 字段重复 | -26
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR	| SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID	| 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC	| 删除成功 | 0
 [↑返回标题↑](#header)



# <a id="delbatch"></a> delBatch
```C++
int delBatch( const vector<DCache::DelCondition> &vtCond, map<taf::Int32, taf::Int32> &mRet )
```
**功能：** 批量删除数据\
**参数：**  
```
vtCond 待删除数据集合，包含主键、删除条件集合与版本号
mRet 键:批量请求中data的index，值:删除结果，大于等于0表示在该mainKey删除的记录条数，其他指示删除失败的原因
```
**用法：**
```c++

    //写法1:
    vector<DCache::DelCondition> vtDelConds;
    auto cond = Rank::uid > 17 && Rank::sex == 1 && Rank::age < 18;
    // 注意，手写DelCondition需要将类型转为string
    vtDelConds.emplace_back("1231424", cond, 0 ); // 删除主键为1231424，且条件为cond的版本号为0的数据
    map<taf::Int32, taf::Int32> &mRet;
    DCacheOpt::getInstance()->getClient().delBatch(vtDelCond,mRet); 
    
    
    // 写法2：
    MultiRowBuilder mbuilder;
    //同个主键下不同ukey，这样写更高效率
    //可以达到or的效果
    //删除
    for(size_t i = 0; i < 5; ++i) {
        auto &oneRow = mbuilder.createDeleteItem("xx1111");
        oneRow.where(uid==i && nickname=="yyy");
    }
    
    //链式写法也是可以的：
    mbuilder.createDeleteItem("xx1111")
            .where(uid==1111 && nickname=="yyy")
            .createDeleteItem("xx1111")
            .where(uid==666666666666 && nickname=="yyy"); //同主键，多个条件
            
    //不同主键或者不同ukey必须这样写
    mbuilder.createDeleteItem("xxx222").where({uid==2222,nickname=="ggsdfg"})
            .createDeleteItem("xxx333").where({uid==3333,nickname=="x34fg"});
    map<int,int>mret;
    ret = DCacheOpt::getInstance()->getClient().delBatch(mbuilder,mret);

    
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_REDUNDANT | 字段重复或字段不存在 | -26
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC	 | 批量删除操作完成 | 0
 [↑返回标题↑](#header)



# <a id="erase"></a> erase
```C++
int erase( const K &sMainIndex )
```
**功能：** 删除缓存中的数据，但不删除DB（如果有）的记录\
**参数：**  
```
sMainIndex 主键
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_ERASE_DIRTY_ERR	| 不允许使用该接口删除脏数据 | -35
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR	| SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID	| 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC	| 删除成功 | 0
 [↑返回标题↑](#header)



# <a id="kkv-select"></a> select
```C++
int select( const K &k, const vector<Field> &vtFields, const vector<Condition> &vtConds, SelectResult &result, bool totalCount = false )
```
**功能：** 根据指定的字段和限制条件查询数据\
**参数：**  
```
k 主键
vtFields 需要查询的字段集, "*"表示所有
vtConds 查询条件集合，除主Key外的其他字段，多个条件直间为And关系
result 查询结果
totalCount 是否返回主key下的总记录条数，注意，如果设置为true，select返回值为该mainkey下的总数据
```
**用法：**
```c++
//用法1，使用SelectResult
SelectResult result;
int iRet = DCacheOpt::getInstance()->getClient().select( "mainkey", SELECT_ALL, {}, result );
if(iRet>0){ //有数据
}

//用法2，使用DCacheRow
DCacheRow row;
//select mainkey下age字段 >10的列，并返回Rank::uid,Rank::name 这两个字段
//相当于sql：'select uid,name from mainkey where age >10;
DCacheOpt::getInstance()->getClient().select( "mainkey", {Rank::uid,Rank::name}, {Rank::age>10}, row );
//可以直接遍历
for (auto &item:row) {
    // 自动将右边的值转换为左边的类型
    long uid = item[Rank::uid];
    string name = item[Rank::name];
    //版本号的获取方法：这是为了打印在log中
    cout << "ver:" << item.getVersionPrint() << endl;
    //如果需要实现cas,应该使用item.getVersion()
}
    
```
**分页查询：** 

在kkv中，select接口支持SELECT_ALL标志，但数据量过大会导致性能问题，为此提供了select conditon的 pos参数，以提供分页ukey的select查找。
`请注意：由于目前的实现中，ukey是使用链表链接，这导致 pos start ,end 的定位操作是O（N）`，所以pos 操作往往典型用途是:
```
1.将DCache设置为insert插入顺序为ukey顺序
2.select 最新的前N条数据：pos 0, N
```
代码如下：
```
DCache_Struct(hash,ukey,value)
SelectResult result;
DBuilder builder;
builder.where(hash::ukey > 1).where(hash::ukey < 10).pos(0, 2);

int iRet = DCacheOpt::getInstance()->getClient().select( "mainkey", SELECT_ALL, builder.genCondition(), result );
if(iRet>0){ //有数据
}
```

**注意：**
 ==TC_Common::strto<int>做DCache版本号转换导致CAS失效==

有人这么用，希望用来做CAS， 100%翻车， 用户说 以前一直没问题， 因为 在0 ~48 ， TC_Common::strto<int>  ===0，0就是CAS 失效，忽略版本了！！ ，但是49后，TC_Common::strto<int>  ===1 ，会报 version_mismatch ，
应该使用` iCacheVersion = DCache::SelectResult::CastVersion(fields["@DataVer"]);`
![image](https://note.youdao.com/yws/res/11241/CEB081A92C0246E8A468D7C6C98CCA53)



**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_NOT_EXIST	| 查询条件集合字段填写错误，无效字段 | -30
 ET_PARAM_REDUNDANT	| 查询条件集合有重复字段或无效字段 | -26
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_NO_DATA | 数据不存在 | -6
 其他值(大于等于0)|记录条数，如果==0说明没有找到符合条件的数据，>0为记录条数，特别地，totalCount为true时，返回了mainkey下所有ukey的个数 | ≥0
 [↑返回标题↑](#header)
 
 
 
# <a id="kkv-selectBatch"></a> selectBatch
```C++
int selectBatch( const vector<K> &vtMainKeys, const vector<Field> &vtFields, const vector<Condition> &vtConds, map<K, SelectResult> &mpKResults )
```
**功能：** 批量查询，不同的主key使用相同的查询条件\
**注意：**  
UKEY 字段为 A 
select 时，condition 设置为 A==1，此MK下有100w数据，问，此次select需要扫描多少条数据？时间复杂度是多少？\
**答案是O(1)**:\
    由于传入的ukey是全字段，所以hash一次即可找到。

如果UKEY 字段为 A B C 呢？
**答案是O(N)**:\
    由于传入的ukey不是全字段，所以只能逐个匹配。

**selectBatch可以支持分页获取：**
带上pos条件即可，注意，这里的pos是插入的序正序或者反序（申请模块时配置）.\
**builder的pos**语义为：先在链表上找出目标条数，然后再按照condition匹配\
**mysql的limit**语义为：先匹配条件，再limit个数
```c++
DBuilder builder;
builder.add(Hash::uid==2341);
builder.pos(0,1000);// 为原limit，但认为limit语义有歧义，故改为position.
```


**参数：**  
```
vtMainKeys 主键集合
vtFields 需要查询的字段集，"*"表示所有
vtConds 查询条件集合，除主Key外的其他字段，多个条件直间为And关系
mpKResults 查询结果集合
```
**用法：**  
```c++

    std::vector<string> vmainKey = {"1234556", "1433223", "50020231", "50020232", "111666111"};
    {
        //1.若 Hash::uid 为ukey，则只有<=1条命中
        DBuilder builder;
        builder.add(Hash::uid==2341);
        
        map<string, SelectResult> mpResults;
        int iRet = DCacheOpt::getInstance()->getClient().selectBatch( vmainKey, SELECT_ALL, builder.vConds, mpResults );
    }

    {
        //2.若 Hash::uid ,Hash::imid 为ukey，但条件只有一个uid，dcache需要遍历
        DBuilder builder;
        builder.add(Hash::uid==2341);
        builder.pos(0,1000);// 为原limit
        map<string, SelectResult> mpResults;
        int iRet = DCacheOpt::getInstance()->getClient().selectBatch( vmainKey, SELECT_ALL, builder.vConds, mpResults );
    }



```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_LIMIT_VALUE_ERR	| 查询条件集合的某个元素的limit属性值填写错误 | -34
 ET_DATA_TOO_MUCH | 数据量过大 | -22
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 批量读取成功 | 0
 [↑返回标题↑](#header)
 
# <a id="kkv-selectBatchOr"></a> selectBatchOr
```C++
int selectBatchOr( const vector<DCache::SelectBatchOrReq> &vtKey, vector<SelectResult>& vtResults, const map<string, string> &context = TAF_CONTEXT() )
int selectBatchOr( const MultiRowBuilder& builder, vector<SelectResult>& vtResults, const map<string, string> &context = TAF_CONTEXT() )
```
**功能：** 批量查询，不同的主key可以使用不同的查询条件，也可以对相同的主key进行查询，实现类似sql：select ... in(a,b,c)的功能\
**注意：**  
UKEY 字段为 A 
select 时，condition 设置为 A==1，此MK下有100w数据，问，此次select需要扫描多少条数据？时间复杂度是多少？\
**答案是O(1)**:\
    由于传入的ukey是全字段，所以hash一次即可找到。

如果UKEY 字段为 A B C 呢？
**答案是O(N)**:\
    由于传入的ukey不是全字段，所以只能逐个匹配。

**selectBatchOr可以支持分页获取：**
带上pos条件即可，注意，这里的pos是插入的序正序或者反序（申请模块时配置）.\
**builder的pos**语义为：先在链表上找出目标条数，然后再按照condition匹配\
**mysql的limit**语义为：先匹配条件，再limit个数
```c++
DBuilder builder;
builder.add(Hash::uid==2341);
builder.pos(0,1000);// 为原limit，但认为limit语义有歧义，故改为position.
```


**参数：**  
```
vtKey 主键集合,包含查询所需信息等
vtResults 查询结果集合

struct SelectBatchOrReq {
    std::string mainKey;
    std::string field;
    vector<DCache::Condition> vtCond;
    taf::Bool bGetMKCout;
}
```
**用法：**  
```c++
    //用法1：直接构造结构体：
    vector<SelectResult> vtResult;
    DBuilder builder;
    builder.add(Hash::UKEY == "10000");

    vector<SelectBatchOrReq> req;

    SelectBatchOrReq s1("123", "*", builder.vConds, false);
    SelectBatchOrReq s2("999888", "*", builder.vConds, false);
    builder.clear();
    builder.add(Hash::UKEY == "1");
    SelectBatchOrReq s3("123", "*", builder.vConds, false);

    req.emplace_back(s1);
    req.emplace_back(s2);
    req.emplace_back(s3);

    int ret = DCacheOpt::getInstance()->getClient().selectBatchOr(req, vtResult);
    
    // 用法2：使用builder，链式表达：
    vector<SelectResult> vtResult;
    MultiRowBuilder builder;
    builder.createSelectBatchOr("123", "*", false).where(Hash::UKEY == "1")
           .createSelectBatchOr("123")
           .createSelectBatchOr("999888");
    int ret = DCacheOpt::getInstance()->getClient().selectBatchOr(builder, vtResult);

    // 用法3：使用builder，保存中间变量：
    auto &selectBatchOrItem = builder.createSelectBatchOr("123", "*", false).where(Hash::UKEY == "1");
    selectBatchOrItem.createSelectBatchOr("123"); //condition为空
    selectBatchOrItem.createSelectBatchOr("999888");
    
    // 处理返回值：
    for(auto &item : vtResult) {
        cout << "mainkey: " << item.getMainKey() << endl; // mk
        cout << "total record: " << item.totalRecords() << endl; // 记录条数
        printSelectResult(item.data()); // 数据
        cout << "=========================" << endl;
    }


```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_LIMIT_VALUE_ERR	| 查询条件集合的某个元素的limit属性值填写错误 | -34
 ET_DATA_TOO_MUCH | 数据量过大 | -22
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 批量读取成功 | 0
 [↑返回标题↑](#header)

# <a id="kkv-scanmk"></a> scanMK
```C++
int scanMK( int index, int count, vector<map<std::string, std::string>> &allVtData, bool &isEnd )
```
**功能：** 根据指定的范围查询哈希表中的数据
**注意事项：**  
1. 由于是遍历哈希桶,当业务总体数据量很少很稀疏时，某次取回来的数据可能是空的，从这点看，参数的count为遍历的哈希桶个数
2. 常规配置，遍历操作是非常慢的，因为默认DCache配置中，哈希桶至少为500w+个，所以当你需要遍历缓存的时，需要在上线时告诉运维配置遍历需求。
3. 如果你的缓存配置包括db，某种情况下，遍历结果可能不包括db中的数据，究其原因，是因为缓存的数据被LRU算法淘汰了。
4. 从以上几点来看，需要变量的缓存数据总量不能太大，常规配置是总体数据量<10w，并要求运维配置缓存容量能hold住全部数据。\


**参数：**  
```
index 游标位置，查询的起始位置
count 查询位置的数量，即查询范围为[index,index+count),注意！是左闭右开区间
allVtData 查询结果
isEnd 是否到达最终位置
```
**用法**：
```c++
void testScanMK()
{
    int index = 0;
    int count = 1000; //每次取1000个，建议不超过5000
    bool isEnd = false;
    
    while( !isEnd ){
        vector<map<std::string, std::string> > vtData;
        DCacheOpt::getInstance()->getClient().scanMK( index, count, vtData, isEnd );
        index += count;
        for( auto &item : vtData )
        {
            for( auto &item2 : item )
            {
                cout << item2.first << "|" << item2.second << endl;
            }
        }
    }
}
```

**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_INPUT_PARAM_ERROR | 参数错误，例如mainKey为空 | -12
 ET_MODULE_NAME_INVALID	| 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC	| 写入成功 | 0
 [↑返回标题↑](#header)

# <a id="kkv-scanmkfromdb"></a> scanMKFromDB
```C++
int scanMKFromDB(const string& servant_name, const string & main_key, int count, vector<map<std::string, std::string>> &allVtData,
                bool &isEnd, string & next_main_key)
```
**功能：** 根据指定的范围查DB中的数据
**注意事项：**  
1. 初始的时候main_key传入为空，以后继续查询需将next_main_key赋值给main_key，不要对next_main_key进行任何修改
 
**参数：**  
```
servant_name DBAccess的servant名
main_key 每次查询时传入的main_key，初始时传入空值
count 查询位置的数量，即查询范围为[index,index+count),注意！是左闭右开区间
allVtData 查询结果
isEnd 是否到达最终位置
next_main_key 下次查询的main_key，不要修改
```
**用法**：
```c++
void testScanMKFromDB()
{
    std::string main_key;
    std::string next_main_key;
    int count = 1000; //每次取1000个，建议不超过5000
    bool isEnd = false;
    string servant_name = "DCache.BenchmarkKKVTestDbAccessServer.DbAccessObj";
    
    while( !isEnd ){
        vector<map<std::string, std::string> > vtData;
        DCacheOpt::getInstance()->getClient().scanMKFromDB( servant_name, main_key, count, vtData, isEnd, next_main_key );
        main_key = next_main_key;
        for( auto &item : vtData )
        {
            for( auto &item2 : item )
            {
                cout << item2.first << "|" << item2.second << endl;
            }
        }
    }
}
```

**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_R_DB_ERR	| rocksDB出错 | -4
 eDbJceDecodeError | JCE解码失败 | -3
 ET_R_ERR | rocksDB 迭代失败 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC	| 写入成功 | 0

[↑返回标题↑](#header)


# <a id="kkv-insert"></a> insert
```C++
int insert( const K &sMainKey, const map<string, UpdateValue> &mpUpdateValues, bool bReplace = false, bool bDirty = true, uint8_t iVer = 0, taf::Int32 tExpire = 0 )
```
**功能：** 写入数据\
**注意：** 
1. insert接口只支持 = 操作符，即如build中的 `xxx=111`，也就是`DCache::Op::SET`
2. bReplace默认为false，本意是在插入数据前先在cache和db查找对应的ukey，如果cache和db都没找到这个ukey则进行插入，否则返回ET_DATA_EXIST.
3. 如果将bReplace设为true，则直接在cache中插入，如果已存在相同的ukey则覆盖

**参数：**  
```
sMainKey 主键
mpUpdateValues 除主键外的其他字段数据
bReplace 默认为false， 如果记录已存在且replace为true时则覆盖旧记录
bDirty 是否设置为脏数据，即数据是否回写db(存在db就应该设为true)
iVer 版本号
tExpire 数据过期时间，为相对时间
```

**用法**：
```c++
//重载了大量操作符，这个简易的ORM 让操作更简单了
DCacheOpt::getInstance()->getClient().insert("242354",{Hash::uid=2341,Hash::name="xxxx",Hash::age=18});

//有时候无法像上例中一行组成需要insert的value的initializelist，如需要多次if else 分支构建数据
//此时我们需要DBuilder
DBuilder builder;
builder.set(Hash::uid=2341);
if(...){
    builder.set(Hash::name="alex");    
}else{
    //default name
    builder.set(Hash::name="我是一颗小虎牙");
}
DCacheOpt::getInstance()->getClient().insert("242354",builder.updateValues,{});


```

**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_OP_ERR	| op错误，只支持SET | -31
 ET_PARAM_NOT_EXIST | 字段不存在 | -30
 ET_PARAM_DIGITAL_ERR | 字段错误，例如值为数字类型的字段包含了非数字字符 | -29
 ET_PARAM_TOO_LONG | 字段大小超过限制 | -28
 ET_PARAM_MISSING | 待写入数据未包含全部联合字段 | -27
 ET_MEM_FULL	| 内存满 | -21
 ET_DATA_VER_MISMATCH | 版本不一致 | -15
 ET_INPUT_PARAM_ERROR | 参数错误，例如mainKey为空 | -12
 ET_FORBID_OPT | 正在迁移，禁止操作 |  -11
 ET_DATA_EXIST | 数据已存在，禁止insert | -10
 ET_SERVER_TYPE_ERR	| SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID	| 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC	| 写入成功 | 0
 [↑返回标题↑](#header)



# <a id="kkv-insertbatch"></a> insertBatch
```C++
int insertBatch( const InsertBatchBuilder &builder, map<int, int> &mpFailReasons )
//builder接口为：
Item createKKVItem( const T &key, taf::Char ver = 0, taf::Bool dirty = true, taf::Bool replace = false, taf::Int32 expireTimeSecond = 0 );
```
**功能：** 批量写入数据\
**参数：**  
```
builder 待写入数据集合，有相当多的语法糖，具体看下面实例用法
mpFailReasons 记录插入失败的原因，key为记录在vtKeyValues中的下标，只有在函数返回值为ET_PARTIAL_FAIL才有效，其他返回值表示全部成功或失败。
请注意：使用MultiRowInserter时，如果同个mk，多个uk，也多次createKKVItem，参考下面例子。
```

**用法**：
```c++
    MultiRowInserter builder;
    auto &oneRow = builder.createKKVItem( 123456 ); //一行记录，注意是引用
    oneRow.set( imname = "alex" );
    oneRow.set( nickname = "nick" );
    //同个mainkey，不同ukey(imname)，也要createKKVItem！！！！！！！！！！！！！！！！！！！！！！
    //写法1 ，使用默认参数
    builder.createKKVItem( 123456 ).set( imname = "alex2" ).set( nickname = "222nick" )
           .createKKVItem( 123457 ).set( imname = "alex3" ).set( nickname = "333nick" )
           .createKKVItem( 123457 ).set( imname = "alex4" ).set( nickname = "333nick" );
           
    //例如期望批量insert，但是需要设置版本，dirty，覆盖写，超时时间功能。           
    //写法2 ，不使用默认参数
    builder.createKKVItem( 123456 ,0,true,true).set( imname = "alex2" ).set( nickname = "222nick" )
           .createKKVItem( 123457 ,0,true,true).set( imname = "alex3" ).set( nickname = "333nick" )
           .createKKVItem( 123457 ,0,true,true).set( imname = "alex4" ).set( nickname = "333nick" );
           
           
    map<int, int> mpFailReasons;
    int ret = DCacheOpt::getInstance()->getClient().insertBatch( builder, mpFailReasons );
    cout << "insertBatch:" << ret << endl;
    
```

**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARTIAL_FAIL | 表示部分数据insert失败 | -16
 ET_SERVER_TYPE_ERR	| SLAVE状态下不提供接口服务 | -9
 ET_MODULE_NAME_INVALID	| 模块名错误 | -2
 ET_SUCC	 | 批量写操作完成 | 0
 [↑返回标题↑](#header)



# <a id="refreshexpiretime"></a> refreshExpiretime
```C++
int refreshExpiretime(const string& mainKey, const vector<Condition>& vtCond, int expireTimeSecond)
```
**功能：** 更新数据的过期时间\
**参数：**  
```
mainKey 主键
vtCond 查询条件集合，除主Key外的其他字段
expireTimeSecond 记录过期时间(秒)，为相对时间
```
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_NOT_EXIST | 字段不存在 | -30
 ET_PARAM_TOO_LONG | 字段大小超过限制 | -28
 ET_PARAM_REDUNDANT	| 字段重复 | -26
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR	| SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID	| 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC	| 操作成功 | 0
 [↑返回标题↑](#header)
 


# <a id="kkv-update"></a> updateOrInsertNotAtom
```C++
int updateOrInsertNotAtom( const K &sMainIndex, const map<string, UpdateValue> &mpUpdateValues, const vector<Condition> &vtConds, bool bDirty = true, uint8_t iVer = 0, time_t tExpire = 0, bool bInsert = false )
```
**功能：** 更新数据,非原子性，可插入\
**参数：**  
```
sMainIndex 主键
mpUpdateValues 需要更新的字段和对应的值，不能填联合key字段
vtConds 数据更新的条件
bDirty  =  是否设置为脏数据，即是否回写db(存在db就应该设为true)
iVer 版本号
tExpire 过期时间，为相对时间
bInsert 如果要修改的唯一记录不存在且insert为true时则插入一条数据
``` 
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_LIMIT_VALUE_ERR | 	更新条件集合的某个元素的limit属性值填写错误 | -34
 ET_PARAM_UPDATE_UKEY_ERR | 更新字段包含了联合字段 | -33
 ET_PARAM_NOT_EXIST | 字段不存在 | -30
 ET_PARAM_DIGITAL_ERR | 字段错误，例如值为数字类型的字段包含了非数字字符 |-29
 ET_PARAM_TOO_LONG | 字段大小超过限制 | -28
 ET_PARAM_REDUNDANT	| 更新条件中的联合字段重复填写 | -26
 ET_DATA_VER_MISMATCH | 版本不一致 | -15
 ET_INPUT_PARAM_ERROR | 参数错误，例如mainKey为空 | -12
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR	| SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID	| 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 其他值(大于等于0)	|更新成功，且此值表示更新操作影响的记录条数 | ≥0
 [↑返回标题↑](#header)



# <a id="kkv-updateatom"></a> updateAtom
```C++
int updateAtom( const K &sMainIndex, const map<string, UpdateValue> &mpUpdateValues, const vector<Condition> &vtConds, bool bDirty = true, time_t tExpire = 0 )
```
**功能：** 原子更新数据,ukey不存在时不会插入数据\
幂等：设置uuid字段，每次更新时带上唯一的uuid，当返回ET_UUID_DUPLICATED时，判定该请求为重复请求，不会对数据进行更新，也不会返回新值/旧值\
**注意：** `原子`的说法来着哪里？实际上，由于DCacheServer是多线程服务，在servant线程从存储引擎取出数据并执行操作时，然后设置回去存储引擎时，如果存在多个线程同时操作同个mainkey，将出现新数据被replace到旧值的问题，`updateAtom`解决了这个问题,所有操作都在存储引擎锁内完成。\
**参数：**  
```
sMainIndex 主键
mpUpdateValues 需要更新的字段和对应的值，不能填联合key字段
vtConds 数据更新的条件
bDirty 是否设置为脏数据，即是否回写db(存在db就应该设为true)
tExpire 过期时间，为相对时间
```
**示例代码：**
```c++
    //对mainKey 下Rank::uid>100000,Rank::sex==1,Rank::age>=18的行，每个age+1（自增操作）
    auto condition = {Rank::uid>100000,Rank::sex==1,Rank::age>=18};
    auto updateValue = {Rank::age+=1};
    DCacheOpt::getInstance()->getClient().updateAtom(mainKey,updateValue,condition);
    //实际上，我们重载了大量操作符
    
    //uuid重试幂等
    builder.clear();
    builder.set( Rank::uid = "123" )
           .set( Rank::__uuid = "1" );
    DCacheOpt::getInstance()->getClient().updateAtom(mainKey,updateValue,condition);
    // retry iRet = ET_UUID_DUPLICATED
    iRet = DCacheOpt::getInstance()->getClient().updateAtom(mainKey,updateValue,condition);
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_UUID_DUPLICATED | 该请求为重复请求(uuid已存在) | -41
 ET_PARAM_LIMIT_VALUE_ERR | 	更新条件集合的某个元素的limit属性值填写错误 | -34
 ET_PARAM_UPDATE_UKEY_ERR | 更新字段包含了联合字段 | -33
 ET_PARAM_NOT_EXIST | 字段不存在 | -30
 ET_PARAM_DIGITAL_ERR | 字段错误，例如值为数字类型的字段包含了非数字字符 | -29
 ET_PARAM_TOO_LONG | 字段大小超过限制 | -28
 ET_PARAM_REDUNDANT	| 更新条件中的联合字段重复填写 | -26
 ET_DATA_VER_MISMATCH | 版本不一致 | -15
 ET_INPUT_PARAM_ERROR | 参数错误，例如mainKey为空 | -12
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR	| SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID	| 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 其他值(大于等于0)	|更新成功，且此值表示更新操作影响的记录条数 | ≥0
 [↑返回标题↑](#header)
 
 

# <a id="kkv-updateatomfetch"></a> updateAtomFetch
```C++
int updateAtomFetch( const K &sMainIndex, const map<string, UpdateValue> &mpUpdateValues, const vector<Condition> &vtConds, SelectResult &result, bool getOldValue = false, bool bDirty = true, time_t tExpire = 0 )
```
**功能：** 原子更新数据,如在vtConds中指定uk的值，则可在uk不存在时插入，可以选择获取新值或者旧值。幂等：设置uuid字段，每次更新时带上唯一的uuid，当返回ET_UUID_DUPLICATED时，判定该请求为重复请求，不会对数据进行更新，也不会返回新值/旧值，但在result中可返回这一uuid首次更新的返回值(@UuidRet)\
！！注意 如果要使用幂等功能，大部分模块都需要升级版本，请联系何嘉俊/练文健\
**参数：**  
```
sMainIndex 主键
mpUpdateValues 需要更新的字段和对应的值，不能填联合key字段
vtConds 数据更新的条件
getOldValue 等于true时获取旧值，false获取新值
bDirty 是否设置为脏数据，即是否回写db(存在db就应该设为true)
tExpire 过期时间，为相对时间
result 查询结果数据集合：
result 包含：
0 @DataVer:   1  
1 @ExpireTime:   0 // 数据过期时间
2 @bInsertSuccess:   1 // 本次更新操作是否插入新数据
3 mk:   123
4 uk:   2
5 v:   1
```

**实例代码**：
```c++


    DBuilder builder;
    builder.clear();
    //各种操作
    builder.set( DCacheUserProfile::nickname = "lisonzhu" );
    builder.set( DCacheUserProfile::roomid &= 18 );
    builder.set( DCacheUserProfile::presenterlevel ^= 1);
    builder.set( DCacheUserProfile::yyid |= 3);
    builder.set( ~DCacheUserProfile::ispresenter);
    SelectResult fetchResult;
    auto iRet = DCacheOpt::getInstance()->getClient().updateAtomFetch( mainKey, builder.updateValues, {}, fetchResult );
    
    //uuid重试幂等
    //！！注意 如果要使用幂等功能，大部分模块都需要升级版本，请联系何嘉俊/练文健
    builder.clear();
    builder.set( DCacheUserProfile::nickname = "lisonzhu" )
           .set( DCacheUserProfile::__uuid = "1" );
    DCacheOpt::getInstance()->getClient().updateAtomFetch( mainKey, builder.updateValues, {}, fetchResult );
    // retry iRet = ET_UUID_DUPLICATED
    iRet = DCacheOpt::getInstance()->getClient().updateAtomFetch( mainKey, builder.updateValues, {}, fetchResult );
```


**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_UUID_DUPLICATED | 该请求为重复请求(uuid已存在) | -41
 ET_PARAM_LIMIT_VALUE_ERR | 	更新条件集合的某个元素的limit属性值填写错误 | -34
 ET_PARAM_UPDATE_UKEY_ERR | 更新字段包含了联合字段 | -33
 ET_PARAM_NOT_EXIST | 字段不存在 | -30
 ET_PARAM_DIGITAL_ERR | 字段错误，例如值为数字类型的字段包含了非数字字符 | -29
 ET_PARAM_TOO_LONG | 字段大小超过限制 | -28
 ET_PARAM_MISSING | 字段缺失 | -27
 ET_PARAM_REDUNDANT	| 更新条件中的联合字段重复填写 | -26
 ET_DATA_VER_MISMATCH | 版本不一致 | -15
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR	| SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID	| 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 其他值(大于等于0)	|更新成功，且此值表示更新操作影响的记录条数 | ≥0
 [↑返回标题↑](#header)

# <a id="kkv-updateatomfetch_v2"></a> updateAtomFetch_v2
```C++
int updateAtomFetch_v2( const K &sMainIndex, const map<string, UpdateValue> &mpUpdateValues, const vector<Condition> &vtConds, SelectResult &result, bool getOldValue = false, bool bDirty = true, bool bInsert = true, time_t tExpire = 0 )
```
**功能：** 原子更新数据,如在vtConds中指定uk的值，则可在uk不存在时插入，可以选择获取新值或者旧值。幂等：设置uuid字段，每次更新时带上唯一的uuid，当返回ET_UUID_DUPLICATED时，判定该请求为重复请求，不会对数据进行更新，也不会返回新值/旧值，但在result中可返回这一uuid首次更新的返回值(@UuidRet)\
**参数：**  
```
sMainIndex 主键
mpUpdateValues 需要更新的字段和对应的值，不能填联合key字段
vtConds 数据更新的条件
result 查询结果数据集合
getOldValue 等于true时获取旧值，false获取新值
bDirty 是否设置为脏数据，即是否回写db(存在db就应该设为true)
bInsert 当ukey不存在时，是否插入
tExpire 过期时间，为相对时间
```

**实例代码**：
```c++


    DBuilder builder;
    builder.clear();
    //各种操作
    builder.set( DCacheUserProfile::nickname = "lisonzhu" );
    builder.set( DCacheUserProfile::roomid &= 18 );
    builder.set( DCacheUserProfile::presenterlevel ^= 1);
    builder.set( DCacheUserProfile::yyid |= 3);
    builder.set( ~DCacheUserProfile::ispresenter);
    SelectResult fetchResult;
    auto iRet = DCacheOpt::getInstance()->getClient().updateAtomFetch( mainKey, builder.updateValues, {}, fetchResult );
    
    //uuid重试幂等
    builder.clear();
    builder.set( DCacheUserProfile::nickname = "lisonzhu" )
           .set( DCacheUserProfile::__uuid = "1" );
    DCacheOpt::getInstance()->getClient().updateAtomFetch( mainKey, builder.updateValues, {}, fetchResult );
    // retry iRet = ET_UUID_DUPLICATED
    iRet = DCacheOpt::getInstance()->getClient().updateAtomFetch( mainKey, builder.updateValues, {}, fetchResult );
```


**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_UUID_DUPLICATED | 该请求为重复请求(uuid已存在) | -41
 ET_PARAM_LIMIT_VALUE_ERR | 	更新条件集合的某个元素的limit属性值填写错误 | -34
 ET_PARAM_UPDATE_UKEY_ERR | 更新字段包含了联合字段 | -33
 ET_PARAM_NOT_EXIST | 字段不存在 | -30
 ET_PARAM_DIGITAL_ERR | 字段错误，例如值为数字类型的字段包含了非数字字符 | -29
 ET_PARAM_TOO_LONG | 字段大小超过限制 | -28
 ET_PARAM_MISSING | 字段缺失 | -27
 ET_PARAM_REDUNDANT	| 更新条件中的联合字段重复填写 | -26
 ET_DATA_VER_MISMATCH | 版本不一致 | -15
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR	| SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID	| 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 其他值(大于等于0)	|更新成功，且此值表示更新操作影响的记录条数 | ≥0
 [↑返回标题↑](#header)


# <a id="kkv-updatefetchbatch"></a> updateFetchBatch
```C++
int updateFetchBatch( const vector<UpdateAtomFetchBatchParam> &updateParam, vector<SelectResult>& vtResults );
struct UpdateAtomFetchBatchParam {
    std::string mainKey;
    map<std::string, DCache::UpdateValue> mpValue;
    vector<DCache::Condition> cond;
    taf::Bool getOldValue;
    taf::Bool dirty;
    taf::Int32 expireTimeSecond;
};

```
**功能：** 批量更新数据,可以,如在cond中指定uk的值，则可在uk不存在时插入，可以选择获取新值或者旧值, 如果在updateParam传入相同的mk，如果都是updateUk，那么可以保证相同mk更新的原子性，如果传入不同的mk，则相当于一次rpc，多次调用updateAtomFetch，并不保证这些不同mk之间的原子性。\
**注意：** 接口返回0表示请求成功，每个mk拥有独立的返回值，是否插入成功需要看各自mk的返回值，返回值处理方法如下方代码所示。\
**参数：**  
```
mainKey 主键, 支持updateParam中存在相同的主键，每个主键都有自己的condition，如果都是updateUk，则对同一mk可以保证原子性
mpValue 需要更新的字段和对应的值，不能填联合key字段
cond 数据更新的条件
getOldValue 等于true时获取旧值，false获取新值
dirty 是否设置为脏数据，即是否回写db(存在db就应该设为true)
expireTimeSecond 过期时间，为相对时间
vtResults 结果数据集合，不一定和传入顺序一致，同一mk顺序与传入顺序一致
```

**实例代码**：
```c++
    //  使用createUpdateItem 构造updateParam
    MultiRowBuilder builder;
    vector<SelectResult> vtResults;
    // createUpdateItem里面可以填jce类型,详细看API_N.h
    bool getOldValue = true;
    bool dirty = true;
    int expireTimeSecond = 0;
    //Item& createUpdateItem(const T& key, taf::Bool getOldValue = false, taf::Bool dirty = true, taf::Int32 expireTimeSecond = 0)
    // 写法1,链式表达
    builder.createUpdateItem("1005",getOldValue,dirty,expireTimeSecond).set(Hash::zzz+="1").where(Hash::timestamp=="1").where(Hash::qqq=="1")
                             .createUpdateItem("1002",!getOldValue).set(Hash::zzz+="1").where(Hash::timestamp=="1").where(Hash::qqq=="2")
                             .createUpdateItem("1002").set(Hash::zzz+="1").where(Hash::timestamp=="2").where(Hash::qqq=="3");
    //写法2，保存中间变量
    auto &updateItem = builder.createUpdateItem("1005",getOldValue,dirty,expireTimeSecond).set(Hash::zzz+="1").where(Hash::timestamp=="1").where(Hash::qqq=="1");
    updateItem.createUpdateItem("1002",!getOldValue).set(Hash::zzz+="1").where(Hash::timestamp=="1").where(Hash::qqq=="2");
    updateItem.createUpdateItem("1002").set(Hash::zzz+="1").where(Hash::timestamp=="2").where(Hash::qqq=="3");
                             
                             
    int ret = DCacheOpt::getInstance()->getClient().updateFetchBatch(builder,vtResults);
    
    // 处理返回值
    for(auto &item : vtResults) {
        cout << item.getMainKey(); //mk
        cout << item.getReturnValue(); //mk对应返回值
        cout << printSelectResult(item.data()); // value
    }
```


**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_ONEKEY_EMPTY | 单个 or batch 接口中，入参，或者入参序列化后的结果 为empty string | -39
 ET_EXCEED_LIMIT | mk的数量超出限制 | -38
 ET_PARAM_LIMIT_VALUE_ERR | 	更新条件集合的某个元素的limit属性值填写错误 | -34
 ET_PARAM_UPDATE_UKEY_ERR | 更新字段包含了联合字段 | -33
 ET_PARAM_NOT_EXIST | 字段不存在 | -30
 ET_PARAM_DIGITAL_ERR | 字段错误，例如值为数字类型的字段包含了非数字字符 | -29
 ET_PARAM_MISSING | 字段缺失 | -27
 ET_PARAM_REDUNDANT	| 更新条件中的联合字段重复填写 | -26
 ET_PARTIAL_FAIL | 部分错误 | -16
 ET_DATA_VER_MISMATCH | 版本不一致 | -15
 ET_INPUT_PARAM_ERROR | 传入的mainkey组为空 | -12
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR	| SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_KEY_INVALID | 无法定位到相应节点 | -3
 ET_MODULE_NAME_INVALID	| 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 成功 | =0
 [↑返回标题↑](#header)
 
 
 # <a id="kkv-callFunction"></a> callFunction (Discard)
```C++
int callFunction(const string& functionName,  const K& mainKey,
                         const vector<Field>& vtFields, const vector<Condition>& vtCond, const map<string, UpdateValue>& mpValue,
                         const map<string, string>& inParam, SelectResult &result, map<string, string>& outParam) 
```
**功能：** 调用ServerLess脚本 \
**参数：**  
```
functionName 函数名

字段 vtFields
vtConds 查找数据的条件
mpValue 传入的函数，对于ServerLess仅透传
inParam 传入的函数，对于ServerLess仅透传
result 返回的数据。由DCache查好数据，传入引用到ServerLess脚本，如果不需要由脚本清空
outParam 回传的函数，仅回传
```


### 介绍：
- ServerLess介绍 http://km.huya.com/index.php?app=group&ac=topic&id=314
- 其中在服务+中使用脚本代码不用特别关注，这部分是DCacheServer的工作

### 开发流程
1. 跟之前一样的申请流程申请DCache, 其中要声明使用CallFunction接口，并提供你定好的脚本名
2. 写好DCache-ServerLess的脚本， 可以参考其他同事的脚本，也可以参考sl_dcache_default.cc（用scripttool下载）
3. 使用scripttool上传脚本
4. 编写业务服务器，调用相应的模块的DCache接口, 建议使用 callFunctionWithVer接口，由调用者指定脚本的版本号即可
5. 测试通过
6. 找运维同学将DCache发布到线上


### 实际调用流程
1. 请求 业务服务器 -> DCacheAPI -> Proxy -> DCache按条件查找数据 -> 你的ServerLess脚本 -> （如果需要）DCache提供给ServerLess的接口
2. 回包 你的ServerLess脚本 -> DCache -> Proxy -> DCacheAPI -> 业务服务器


### DCache提供给ServerLess的接口
使用scripttool下载 mkcacheserver_ass_export.h 可以看到所有的接口

提供的功能有:insert/update/del/refershtime等接口
 
目前的返回码跟DCacheAPI返回码基本是一样的。不一样的是，Update成功也是返回ET_SUCC

### 如何写脚本
脚本的函数需要固定的参数，脚本名跟函数名自定。

```c++
/**
 *功能：测试ServerLess功能, 样例, 注意原型不能更改
 *参数说明：
 *  content：当前DCache所处的上下文，回传参数，由于ServerLess传void指针出错，
 *           请将content转为void*传入JMemHashXXX
 *
 *  mk：     主key
 *  mpValue: 更新的结构, 更新的结构进来前会有判断，跟普通update类似，
 *           只能传已经存在的field, 不能传ukey/mainkey等
 *
 *  inParam:    额外转入的参数，做进一步控制用, 如需要复合结构请使用JCE封装
 *  vtData： 根椐客户端传过来的vtCond查询到的数据，此结果会回传给客户端, 如果不需要返回给客户端，需要调用clear清理数据
 *  outParam:    额外转回的参数，丰富返回结果, 如需要复合结构请使用JCE封装 
 *  getRet： 根椐vtCond查询数据时的结果, 一般情况下不需要使用
 *@return int, 
 *  返回给客户端的ret值，由脚本来控制
 */
 

int test_ServerLess(uint64_t content, const std::string& mk, 
                    const std::map<std::string, DCache::UpdateValue>& mpValue,
                    const std::map<std::string, std::string>& inParam,
                    std::vector<std::map<std::string, std::string> >& vtData, 
                    std::map<std::string, std::string>& outParam, int getRet) {
                    vtData.clear();
                    return ET_SUCC;
}

```

#### 警告
vtData： 根椐客户端传过来的vtCond查询到的数据，此结果会回传给客户端, 如果不需要返回给客户端，需要调用clear清理数据

由于这个问题已经出过事故，所以每个写脚本，特别是统计脚本的人注意

事故： 由于之前没有郑重沟通过这个事情，useronlinestate 统计在线人数时没有清除vtData, 导致包过大产生一系列错误

####  getret参考列表
```
@return int:
TC_Multi_HashMap_Malloc::RT_NO_DATA: 没有数据
TC_Multi_HashMap_Malloc::RT_READONLY: 只读模式
TC_Multi_HashMap_Malloc::RT_ONLY_KEY:只有Key
TC_Multi_HashMap_Malloc::RT_OK:获取数据成功
TC_Multi_HashMap_Malloc::RT_LOAD_DATA_ERR: load数据失败
其他返回值: 错误

enum 
    {    
        RT_OK                   = 0,    //成功
        RT_DIRTY_DATA           = 1,    //脏数据
        RT_NO_DATA              = 2,    //没有数据
        RT_NEED_SYNC            = 3,    //需要回写
        RT_NONEED_SYNC          = 4,    //不需要回写
        RT_ERASE_OK             = 5,    //淘汰数据成功
        RT_READONLY             = 6,    //map只读
        RT_NO_MEMORY            = 7,    //内存不够
        RT_ONLY_KEY             = 8,    //只有Key, 没有Value
        RT_NEED_BACKUP          = 9,    //需要备份
        RT_NO_GET               = 10,   //没有GET过
        RT_DATA_VER_MISMATCH    = 11,   //写入数据版本不匹配
        RT_PART_DATA            = 12,   //主key数据不完整
        RT_DATA_EXIST           = 13,   //设置OnlyKey时的返回，表示实际上有数据
        RT_DATA_EXPIRED         = 14,   //数据已过期 
        RT_DATA_DEL             = 15,   //数据已删除

        ////////////////////////2018年12月20日 12:17:31 以后添加返回码，都写负数/////////////////////////////////////////
        RT_JUDGE_NODATA         = -50,  //用在updateFetch，但是目前客户端返回的是0
        RT_DECODE_ERR           = -1,   //解析错误
        RT_EXCEPTION_ERR        = -2,   //异常
        RT_LOAD_DATA_ERR        = -3,   //加载数据异常
        RT_VERSION_MISMATCH_ERR = -4,   //版本不一致
        RT_DUMP_FILE_ERR        = -5,   //dump到文件失败
        RT_LOAD_FILE_ERR        = -6,   //load文件到内存失败
        RT_NOTALL_ERR           = -7,   //没有复制完全
        RT_NOT_FOUND_FUNC       = -8,
    };   
```

#### 返回值
DCache与ServerLess共用一个返回值。建议一般情况下返回ET_SUCC, 
错误情况需要传回返回码请与DCache系统返回码区分开来，比如使用-10000代表脚本的某种错误

返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC	|成功 | 0
 [↑返回标题↑](#header)

```C++
int callFunction(const string& functionName, const K& mainKey,
                         const vector<Field>& vtFields, const vector<Condition>& vtCond, const map<string, UpdateValue>& mpValue,
                         const map<string, string>& inParam, SelectResult &result, map<string, string>& outParam) 
```
**功能：** 调用ServerLess脚本 \
**参数：**  
```
functionName 函数名
字段 vtFields
vtConds 查找数据的条件
mpValue 传入的函数，对于ServerLess仅透传
inParam 传入的函数，对于ServerLess仅透传
result 返回的数据。由DCache查好数据，传入引用到ServerLess脚本，如果不需要由脚本清空
outParam 回传的函数，仅回传
```



# <a id="kkv-callFunctionWithVer"></a> callFunctionWithVer
```C++
int callFunctionWithVer(const string& functionName, int functionVer, const K& mainKey,
                         const vector<Field>& vtFields, const vector<Condition>& vtCond, const map<string, UpdateValue>& mpValue,
                         const map<string, string>& inParam, SelectResult &result, map<string, string>& outParam) 
```
**功能：** 调用ServerLess脚本 \
**参数：**  
```
functionName 函数名
functionVer 脚本的版本
字段 vtFields
vtConds 查找数据的条件
mpValue 传入的函数，对于ServerLess仅透传
inParam 传入的函数，对于ServerLess仅透传
result 返回的数据。由DCache查好数据，传入引用到ServerLess脚本，如果不需要由脚本清空
outParam 回传的函数，仅回传
```

**实例代码**：
```c++
    
```


**返回值**：
DCache与ServerLess共用一个返回值。建议一般情况下返回ET_SUCC, 
错误情况需要传回返回码请与DCache系统返回码区分开来，比如使用-10000代表脚本的某种错误

返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC	|成功 | 0
 [↑返回标题↑](#header)

```C++
int callFunction(const string& functionName, const K& mainKey,
                         const vector<Field>& vtFields, const vector<Condition>& vtCond, const map<string, UpdateValue>& mpValue,
                         const map<string, string>& inParam, SelectResult &result, map<string, string>& outParam) 
```
**功能：** 调用ServerLess脚本 \
**参数：**  
```
functionName 函数名
字段 vtFields
vtConds 查找数据的条件
mpValue 传入的函数，对于ServerLess仅透传
inParam 传入的函数，对于ServerLess仅透传
result 返回的数据。由DCache查好数据，传入引用到ServerLess脚本，如果不需要由脚本清空
outParam 回传的函数，仅回传
```

# <a id="list-getlist"></a> getList
```C++
int getList( const K &sMainKey, const vector<Field> &vtFields, taf::Int64 iPos, SelectResult &result )
```
**功能：** 根据指定的主键和索引查询数据\
**参数：**
```
sMainKey 主键
vtFields 需要查询的字段集，"*"表示所有
iPos 索引
result 查询结果
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 查询成功 | 0
 [↑返回标题↑](#header)
 
 

# <a id="list-getrangelist"></a> getRangeList
```C++
int getRangeList( const std::string &mainKey, const vector<string> &field, taf::Int64 iStart, taf::Int64 iEnd, SelectResult &result )
```
**功能：** 根据指定的主键查找索引值在区间[startIndex, endIndex]的数据\
**参数：**
```
mainKey 主键
field 需要查询的字段集， "*"表示所有
iStart 开始索引
iEnd 结束索引
result 查询结果集合
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 查询成功 | 0
 [↑返回标题↑](#header)
 
 

# <a id="list-pushlist"></a> pushList
```C++
int pushList( const K &sMainKey, const MultiRowInserter &builder, taf::Bool bHead = false )
```
**功能：** 在list头部或者尾部插入数据，支持批量操作\
**参数：**
```
sMainKey 主键
builder 待插入数据
bHead true表示插入到list头部，false表示插入尾部
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_PARAM_DIGITAL_ERR | 字段错误，例如值为数字类型的字段包含了非数字字符 | -29
 ET_PARAM_TOO_LONG | 字段大小超过限制 | -28
 ET_PARAM_OP_ERR	| op错误，只支持SET | -31
 ET_PARAM_NOT_EXIST | 字段不存在 | -30
 ET_MEM_FULL | 内存不足 | -21
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 成功写入数据 | 0
 [↑返回标题↑](#header)
 
 

# <a id="list-poplist"></a> popList
```C++
int popList( const K &sMainKey, taf::Bool bHead, SelectResult &result )
```
**功能：** 从list头部或者尾部删除一条数据\
**参数：**
```
sMainKey 主键
bHead true表示从list头部删除，false表示尾部删除
result 被删除的数据
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_NO_DATA | 数据不存在 | -6
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 成功删除 | 0
 [↑返回标题↑](#header)
 
 

# <a id="list-replacelist"></a> replaceList
```C++
int replaceList( const K &sMainKey, const map<std::string, DCache::UpdateValue> &mpValue, taf::Int64 iPos, int iExpireTime )
```
**功能：** 根据指定主键更新list上指定索引的数据\
**参数：**
```
sMainKey 主键
mpValue 新数据
iPos 待替换数据在列表中的索引
iExpireTime 过期时间 为绝对时间
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_OP_ERR	| op错误，只支持SET | -31
 ET_PARAM_NOT_EXIST | 字段不存在 | -30
 ET_PARAM_DIGITAL_ERR | 字段错误，例如值为数字类型的字段包含了非数字字符 | -29
 ET_PARAM_TOO_LONG | 字段大小超过限制 | -28
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 替换成功 | 0
 [↑返回标题↑](#header)



# <a id="list-trimlist"></a> trimList
```C++
int trimList( const K &sMainKey, taf::Int64 iStart, taf::Int64 iEnd )
```
**功能：** 裁剪列表，只保留指定区间：[iStart, iEnd]内的数据，删除区间外的数据\
**参数：**
```
sMainKey 主键
iStart 开始索引
iEnd 结束索引
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 操作成功 | 0
 [↑返回标题↑](#header)
 


# <a id="list-remlist"></a> remList
```C++
int remList( const K &sMainKey, taf::Bool bHead, taf::Int64 iCount )
```
**功能：** 从列表头部或者尾部删除一条或多条数据\
**参数：**
```
sMainKey 主键
bHead true表示从list头部删除，false表示从尾部删除
iCount 指定删除数据条数
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_NO_DATA	| 数据不存在 | -6
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 删除条数 | ≥0
 [↑返回标题↑](#header)
 
 

# <a id="set-getset"></a> getSet
```C++
int getSet( const K &mainKey, const vector<Field> &vtFields, SelectResult &result )
```
**功能：** 查询数据\
**参数：**
```
mainKey 主键
vtFields 需要查询的字段集， "*"表示所有
result 查询结果集合
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 查询成功 | 0
 [↑返回标题↑](#header)
 


# <a id="set-isinset"></a> isInSet
```C++
int isInSet( const K &mainKey, const map<std::string, DCache::UpdateValue> &mpValue , bool &bInSet )
```
**功能：** 判断指定的数据记录是否在Set中\
**参数：**
```
mainKey 主键
mpValue 其他字段数据
bInSet 返回结果，是否在Set中
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_OP_ERR	| op错误，只支持EQ | -31
 ET_PARAM_NOT_EXIST | 字段不存在 | -30
 ET_PARAM_DIGITAL_ERR | 字段错误，例如值为数字类型的字段包含了非数字字符 | -29
 ET_PARAM_TOO_LONG | 字段大小超过限制 | -28
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 成功删除数据 | 0
 [↑返回标题↑](#header)
 
 
 
# <a id="set-addset"></a> addSet
```C++
int addSet( const K &mainKey, const map<std::string, DCache::UpdateValue> &mpValue, int iExpireTime, taf::Char iVersion, taf::Bool bDirty )
```
**功能：** 写入数据\
**参数：**
```
mainKey 主键
mpValue 其他字段数据
iExpireTime 过期时间，为相对时间
iVersion 版本号
bDirty 是否设置为脏数据，即是否回写db(存在db则应设为true)
```
**示例代码**：
```C++
DCache_Struct(Hash,timestamp,count,xxx)
DBuilder builder;
builder.set(Hash::uid=2341);
builder.set(Hash::timestamp=2020);
string main_key("test_add_set");
int expire_time = 0;
char version = 0;
bool dirty = true;
int ret = DCacheOpt::getInstance()->getClient().addSet(main_key, builder.genUpdateValues(), expire_time, version, dirty);

```

**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_OP_ERR	| op错误，只支持SET | -31
 ET_PARAM_NOT_EXIST | 字段不存在 | -30
 ET_PARAM_DIGITAL_ERR | 字段错误，例如值为数字类型的字段包含了非数字字符 | -29
 ET_PARAM_TOO_LONG | 字段大小超过限制 | -28
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 成功写入数据 | 0
 [↑返回标题↑](#header)



# <a id="set-delset"></a> delSet
```C++
int delSet( const K &mainKey, const vector<DCache::Condition> &vtCond )
```
**功能：** 删除数据，只能删除一条数据\
**参数：**
```
mainKey 主键
vtCond 条件集合 只支持EQ
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_OP_ERR	| op错误，只支持EQ | -31
 ET_PARAM_MISSING | 字段缺失 | -27
 ET_PARAM_REDUNDANT | 字段重复或字段不存在 | -26
 ET_DB_ERR | 数据库错误 | -24
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 成功删除数据 | 0
 [↑返回标题↑](#header)
 
# <a id="zset-field"></a> ZSet隐藏字段
```
@ScoreValue : ZSet的分数
```
 
# <a id="zset-getscore"></a> getScoreZSet
```C++
int getScoreZSet( const K &mainKey, const vector<DCache::Condition> &vtCond, taf::Double &iScore )
```
**功能：** 根据指定条件，查询某条记录的分值\
**参数：**
```
mainKey 主键
vtCond 条件集合
iScore 查询结果：记录的分值
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_OP_ERR	| op错误，只支持EQ | -31
 ET_PARAM_MISSING | 字段缺失 | -27
 ET_PARAM_REDUNDANT | 字段重复或字段不存在 | -26
 ET_DB_ERR | 数据库错误 | -24
 ET_NO_DATA | 条件指定的数据不存在 | -6
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 查询成功 | 0
 [↑返回标题↑](#header)
 


# <a id="zset-getrank"></a> getRankZSet
```C++
int getRankZSet( const K &mainKey, const vector<DCache::Condition> &vtCond, bool bOrder, taf::Int64 &iPos )
```
**功能：** 根据指定条件，查询某条记录在已排序列表的索引位置\
**参数：**
```
mainKey 主键
vtCond 条件集合
bOrder true表示按正序查找，false表示逆序查找
iPos 查询结果：记录的在已排序列表的索引位置
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_OP_ERR	| op错误，只支持EQ | -31
 ET_PARAM_MISSING | 字段缺失 | -27
 ET_PARAM_REDUNDANT | 字段重复或字段不存在 | -26
 ET_DB_ERR | 数据库错误 | -24
 ET_NO_DATA | 条件指定的数据不存在 | -6
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 查询成功 | 0
 [↑返回标题↑](#header)
 


# <a id="zset-getrankandscore"></a> getRankAndScoreZSet
```C++
int getRankAndScoreZSet( const K &mainKey, const vector<DCache::Condition> &vtCond, bool bOrder, taf::Int64 &iPos, taf::Double &iScore )
```
**功能：** 根据指定条件，查询某条记录在已排序列表的分值以及索引位置\
**参数：**
```
mainKey 主键
vtCond 条件集合
bOrder true表示按正序查找，false表示逆序查找
iPos 查询结果：记录的在已排序列表的索引位置
iScore 查询结果：记录的分值
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_OP_ERR	| op错误，只支持EQ | -31
 ET_PARAM_MISSING | 字段缺失 | -27
 ET_PARAM_REDUNDANT | 字段重复或字段不存在 | -26
 ET_DB_ERR | 数据库错误 | -24
 ET_NO_DATA | 条件指定的数据不存在 | -6
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 查询成功 | 0
 [↑返回标题↑](#header)
 
 
# <a id="zset-getrankandscoreBatch"></a> getRankAndScoreZSetBatch
```C++
int getRankAndScoreZSetBatch(const vector<DCache::RankAndScoreKey>& keyInfo, bool bOrder,DCache::GetRankAndScoreZSetBatchRsp &rsp)
```
**getRankAndScoreZSetBatch 支持一个 mainkey 带一个 value condition。 如果同一个 mainkey 带不同的 value condition 时，返回结果的顺序与传入 mainkey 顺是一致的,
getRankZset与getScoreZset的实现与getRankAndScoreZset性能一样，所以前两者的批量接口需求可以用getRankAndScoreZSetBatch代替。
**

**功能：** 根据指定条件，批量查询某条记录在已排序列表的分值以及索引位置

**参数：**
```
struct RankAndScoreKey
{
    string sMainKey;    
    vector<Condition> vtCond; //value condition
};

struct GetRankAndScoreZSetBatchRsp
{
    vector<RankAndScoreValue> value;
};
struct RankAndScoreValue
{
    string mainKey; 
    long iPos;          //满足条件的的rank值
    double dScore;      //满足条件的score值
    int ret;            // 返回值
};
```
**使用方法：**
```C++

    MultiRowBuilder MBuilder;
    MBuilder.createGetRankAndScoreItem("test0").where(ZSet::value1==18).where(ZSet::value2==1) //mk为test0 条件为value1==18与value2==1
            .createGetRankAndScoreItem("test1").where(ZSet::value1==22).where(ZSet::value2==1)
            .createGetRankAndScoreItem("test2").where(ZSet::value1==26).where(ZSet::value2==0);
    DCache::GetRankAndScoreZSetBatchRsp rsp;

    bool bOrder = true;//使用递增序列
    int ret = DCacheOpt::getInstance()->getClient().getRankAndScoreZSetBatch(MBuilder, bOrder,rsp);
    
    //打印返回结果
    for(auto& item : rsp.value){
        cout <<"mk: "<<item.mainKey<<endl;
        cout <<"    position: "<<item.iPos<<endl;
        cout <<"    score: "<<item.dScore<<endl;
        cout <<"    ret: "<<item.ret<<endl;
        cout <<"------------------------------------------------------------"<<endl;
    }
    cout << "ret " <<ret<<endl;
```



# <a id="zset-getrange"></a> getRangeZSet
```C++
int getRangeZSet( const K &mainKey, const std::string &field, taf::Int64 iStart, taf::Int64 iEnd, taf::Bool bUp, SelectResult &result )
```
**功能：** 查询索引区间[iStart, iEnd]内的数据,注意：是闭区间\
**参数：**
```
mainKey 主键
field 需要查询的字段集，多个字段用','分隔如 "a,b", "*"表示所有
iStart 开始索引,从0开始
iEnd 结束索引
bUp true表示返回的结果按递增排序，false表示递减
result 查询结果数据集合
```
**注意:**
```
bUp为true时，查询是以iStart为起始位置，向score递增方向查询
bUp为false时，查询是从 总元素个数 - iEnd + 1 处起，向score递增的方向查询，
             查询 IEnd - iStart + 1 个元素
```

**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_DB_ERR | 数据库错误 | -24
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 查询成功 | 0
 [↑返回标题↑](#header)
 
 
 # <a id="zset-getrangebatch"></a> getRangeZSetBatch
```C++
int getRangeZSetBatch( const vector<DCache::GetRangeZSetBatchInfo> & vtInfo, const std::string & field, taf::Bool bUp, vector<SelectResult>& vtResults )
```
**功能：** getRangeZSet的批量接口,除了该接口的返回值以外，每个mainKey都有自己的返回值，可以传入相同的mainKey\
**参数：**
```
struct GetRangeZSetBatchInfo {
    std::string mainKey;
    taf::Int64 iStart; //开始索引,从0开始
    taf::Int64 iEnd; //结束索引
};
vtInfo 主键相关信息
field 需要查询的字段集，多个字段用','分隔如 "a,b", "*"表示所有
bUp true表示返回的结果按递增排序，false表示递减
vtResults 查询结果数据集合
```
使用方法：
```c++
    //使用MultiRowBuilder构造GetRangeZSetBatchInfo
    MultiRowBuilder builder;
    vector<SelectResult> vtResults;
    builder.createGetRangeItem("111",0,10)//mk为"111",位置[0,10]
           .createGetRangeItem("222",10,20);//mk为"222",位置[10,20]
    bool bUp = true;//假设使用递增排序
    int iRet = DCacheOpt::getInstance()->getClient().getRangeZSetBatch(builder,"*",bUp,vtResults);
    //处理vtResults
    for(auto &item : vtResults) {
        string mk = item.getMainKey();//获取mk,注意！结果顺序和传入的顺序不一定一致(同一个mk顺序一致)
        int ret = item.getReturnValue();//获取该mk对应的返回值,不是上面的iRet！
        auto value = item.data();//获取value
    }
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_ONEKEY_EMPTY | 单个 or batch 接口中，入参，或者入参序列化后的结果 为empty string | -39
 ET_EXCEED_LIMIT | batch接口中key数量超出限制 | -38
 ET_DB_ERR | 数据库错误 | -24
 ET_FORBID_OPT | 禁止任何操作，比如在进行数据迁移时 | -11
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_KEY_INVALID | 无效的索引 | -3
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 查询成功 | 0

 [↑返回标题↑](#header)



# <a id="zset-getrangebyscore"></a> getRangeZSetByScore
```C++
int getRangeZSetByScore( const K &mainKey, const std::string &field, taf::Double iMin, taf::Double iMax, SelectResult &result )
```
**功能：** 查询分值区间[minScore, maxScore]内的数据，注意：是闭区间\
**参数：**
```
mainKey 主键
field 需要查询的字段集，多个字段用','分隔如 "a,b", "*"表示所有
iMin 最小分值
iMax 最大分值
result 查询结果数据集合
```

**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_DB_ERR | 数据库错误 | -24
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 查询成功 | 0
 [↑返回标题↑](#header)
 
 
 
# <a id="zset-selectbatch"></a> getRangeZSetByScoreBatch
```C++
//每个mainkey支持带不同condition
int getRangeZSetByScoreBatch(const vector<RangeZSetByScoreKey> & keyInfo, const std::string& field,  map<string, SelectResult>& result)

//所有的mainkey带统一condition
int getRangeZSetByScoreBatch(const vector<K> &vtMainKeys, const vector<Field> &vtFields, const vector<Condition> &vtConds, map<K, SelectResult>& result)
```
**使用推荐(本接口不支持带 value condition)：** 
- 若带了vtValueCond和vtScoreCond，性能将非常差，已不推荐使用，可以拿回来自己过滤value
- 若不带vtValueCond和vtScoreCond，其语义为：getRangeZset，请用getRangeZSetBatch代替；
- 若希望单独使用带vtScoreCond的接口，即希望使用get 分数区间的zset数据，应该使用getRangeZSetByScoreBatch；
- 若希望单独使用带ValueCondition ，使用getRankAndScoreZSetBatch代替。

\
**功能：** 批量查询多个主键的ZSet中指定的数据记录\
**参数：**
```
1、keyInfo 主键集合
    struct RangeZSetByScoreKey
    {
        string mainKey;
        vector<Condition> cond;
    };
2、field 需要查询的字段集， "*"表示所有
3、result 查询结果 
    class SelectResult
    {
    public:
        // @return, vector<map<string, string>>，所有字段值都以string保存，需要自己进行数据类型的转换
        vector<map<string, string> > &data();
        //@return size_t, 记录条数
        size_t size();
        //清空结果集
        void clear();
        //获取查询结果
        int &getReturnValue()
    };

```
**使用方法**
```C++
DCache_Struct(ZSet,uid,value1,value2,ScoreValue)

// 用法一:
    MultiRowBuilder MBuilder;
    MBuilder.createGetRangeZSetByScoreItem("test0").where(ZSet::ScoreValue > 0).where(ZSet::ScoreValue < 500).pos(0,10)//这里表示的是在 0 到 500 之间取位置在 0 到 10 的元素
            .createGetRangeZSetByScoreItem("test1").where(ZSet::ScoreValue > 0).where(ZSet::ScoreValue < 500).pos(0,10)
            .createGetRangeZSetByScoreItem("test2").where(ZSet::ScoreValue > 0).where(ZSet::ScoreValue < 500).pos(0,10);
    
     //用法二：
    vector<RangeZSetByScoreKey> keyInfo;
    vector<Condition> cond;
    vector<string> mainKey = {"test0", "test1", "test2"};
    for(auto& item : mainKey){
        RangeZSetByScoreKey tmpKeyInfo;
        tmpKeyInfo.mainKey = item;
        Condition tmpCond;
        // score condition 
        tmpKeyInfo.cond.emplace_back(std::move(ZSet::ScoreValue > 0));
        tmpKeyInfo.cond.emplace_back(std::move(ZSet::ScoreValue < 500));
        //Limit 条件
        tmpCond.fieldName = "";
        tmpCond.op = DCache::LIMIT;
        tmpCond.value = TC_Common::tostr( 0 ) + ":" + TC_Common::tostr( 10 ); // 用:分隔
        tmpKeyInfo.cond.emplace_back(std::move(tmpCond));
        keyInfo.emplace_back(tmpKeyInfo);
    }
    
    string field = "*";//查询全部 field = "* ；查询部分 filed = "field1,field2"
    map<string, SelectResult> result;
    //用法一：
    int ret = DCacheOpt::getInstance()->getClient().getRangeZSetByScoreBatch(MBuilder, field, result);
    //用法二：
    int ret = DCacheOpt::getInstance()->getClient().getRangeZSetByScoreBatch(keyInfo, field, result);
    cout << "ret: "<< ret <<endl;
    for(auto& item : result){
        cout<<"mk:    "<<item.first<<endl; 
        cout<<"     ret:"<<item.second.getReturnValue()<<endl;//返回值
        
        for(auto& it : item.second.data())
        {
            cout <<"      value:"<<endl;
            for(auto& tmp : it)
            {
                cout<<"         "<<tmp.first<<" : "<<tmp.second<<endl;
            }
        }
        cout<<"======================================="<<endl;
    }
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_LIMIT_VALUE_ERR | 更新条件集合的某个元素的limit属性值填写错误 | -34
 ET_PARAM_REDUNDANT	| 字段重复 | -26
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 查询成功 | 0
 [↑返回标题↑](#header)
 
 
 
# <a id="zset-addzset"></a> addZSet
```C++
int addZSet( const K &mainKey, const map<std::string, DCache::UpdateValue> &mpValue, taf::Double score, int iExpireTime, taf::Char iVersion, taf::Bool bDirty)
```
**功能：** 将带有给定分值的数据添加到有序集合中，如果数据已存在，则重置其分值为score，（即覆盖）\
**参数：**
```
mainKey 主键
mpValue 其他字段数据
score 待写入数据分值
iExpireTime 数据过期时间, 为相对时间
iVersion 版本号
bDirty 是否设置为脏数据，即是否回写db(存在db则应设为true)
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_OP_ERR | op错误，只支持SET | -31
 ET_PARAM_NOT_EXIST | 字段不存在 | -30
 ET_PARAM_DIGITAL_ERR | 字段错误，例如值为数字类型的字段包含了非数字字符 | -29
 ET_PARAM_TOO_LONG | 字段大小超过限制 | -28
 ET_MEM_FULL | 内存满 | -21
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 添加成功 | 0
 [↑返回标题↑](#header)
 


# <a id="zset-incscore"></a> incScoreZSet
```C++
int incScoreZSet( const K &mainKey, const map<std::string, DCache::UpdateValue> &mpValue, taf::Double score, int iExpireTime, taf::Char iVersion, taf::Bool bDirty )
```
**功能：** 修改（在原有分数上加减）有序集合中某条记录的分值，若数据不存在，则新建一条数据，新数据的分值为score\
**参数：**
```
mainKey 主键
mpValue 指定数据，可作为条件查找记录或者新数据
score 分数变化值，可以是负数
iExpireTime 数据过期时间，为相对时间
iVersion 版本号
bDirty 是否设置为脏数据，即是否回写db(存在db则应设为true)
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_OP_ERR | op错误，只支持SET | -31
 ET_PARAM_NOT_EXIST | 字段不存在 | -30
 ET_PARAM_DIGITAL_ERR | 字段错误，例如值为数字类型的字段包含了非数字字符 | -29
 ET_PARAM_TOO_LONG | 字段大小超过限制 | -28
 ET_MEM_FULL | 内存满 | -21
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 添加成功 | 0
 [↑返回标题↑](#header)
 


# <a id="zset-incscoreex"></a> incScoreZSetEx
```C++
int incScoreZSetEx( const K &mainKey, const map<std::string, DCache::UpdateValue> &mpValue, taf::Double score, int iExpireTime, taf::Char iVersion, taf::Bool bDirty, IncScoreZSetExResult &tResult)
```
**功能：** 修改（在原有分数上加减）有序集合中某条记录的分值，若数据不存在，则新建一条数据，新数据的分值为score，并返回结果\
**参数：**
```
mainKey 主键
mpValue 指定数据，可作为条件查找记录或者新数据
score 分数变化值，可以是负数
iExpireTime 数据过期时间，为相对时间
iVersion 版本号
bDirty 是否设置为脏数据，即是否回写db(存在db则应设为true)
tResult 包含本次操作是否导致新增元素，新旧分数以及新旧升降序排名
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_OP_ERR | op错误，只支持SET | -31
 ET_PARAM_NOT_EXIST | 字段不存在 | -30
 ET_PARAM_DIGITAL_ERR | 字段错误，例如值为数字类型的字段包含了非数字字符 | -29
 ET_PARAM_TOO_LONG | 字段大小超过限制 | -28
 ET_MEM_FULL | 内存满 | -21
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 添加成功 | 0
 [↑返回标题↑](#header)
 
 
 
# <a id="zset-del"></a> delZSet
```C++
int delZSet( const K &mainKey, const vector<DCache::Condition> &vtCond )
```
**功能：** 删除有序集合中符合指定条件的某条数据\
**参数：**
```
mainKey 主键
vtCond 条件集合，用来确定唯一一条数据，仅EQ
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_OP_ERR	| op错误，只支持EQ | -31
 ET_PARAM_MISSING | 字段缺失 | -27
 ET_PARAM_REDUNDANT | 字段重复或字段不存在 | -26
 ET_DB_ERR | 数据库错误 | -24
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 删除成功 | 0
 [↑返回标题↑](#header)
 


# <a id="zset-delrange"></a> delRangeZSet
```C++
int delRangeZSet( const K &mainKey, taf::Double iMin, taf::Double iMax )
```
**功能：** 从有序集合中删除分值在区间[iMin, iMax]的数据\
**参数：**
```
mainKey 主键
iMin 最小分值
iMax 最大分值
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_DB_ERR | 数据库错误 | -24
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 删除成功 | 0
 [↑返回标题↑](#header)



# <a id="zset-update"></a> updateZSet
```C++
int updateZSet( const K &mainKey, const map<std::string, DCache::UpdateValue> &mpValue, const vector<DCache::Condition> &vtCond, int iExpireTime, taf::Char iVersion, taf::Bool bDirty )
```
**功能：** 根据指定条件更新有序集合的某条数据\
**参数：**
```
mainKey 主键
mpValue 其他字段数据
vtCond 条件集合，用来确定唯一一条数据
iExpireTime 数据过期时间，为相对时间
iVersion 版本号
bDirty 是否设置为脏数据，即是否回写db(存在db则应设为true)
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_OP_ERR | op错误，只支持EQ | -31
 ET_PARAM_NOT_EXIST | 字段不存在 | -30
 ET_PARAM_DIGITAL_ERR | 字段错误，例如值为数字类型的字段包含了非数字字符 | -29
 ET_PARAM_TOO_LONG | 字段大小超过限制 | -28
 ET_PARAM_MISSING | 字段缺失 | -27
 ET_PARAM_REDUNDANT | 字段重复或字段不存在 | -26
 ET_DB_ERR | 数据库错误 | -24
 ET_INPUT_PARAM_ERROR | mainKey为空 | -12
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 更新成功 | 0
 [↑返回标题↑](#header)
 
 
  
# <a id="kv-get-API-N"></a> get(API_N)
```C++
int getString(const K& mainKey,string &val)
int getString(const K& mainKey,string &val ,taf::Char& ver)
```
**功能：** 获取值，不关心版本号/带版本号\
**参数：**
```
mainKey 主键
val 结果
ver 版本号
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_NO_DATA | 数据不存在 | -6
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 更新成功 | 0
 [↑返回标题↑](#header)



# <a id="kv-getbatch-API-N"></a> getBatch(API_N)
```C++
template<typename V>
BatchKeyValues<V> getBatch(const vector<K>& keys)
```
**功能：** 批量获取值 注意！ret包含整体返回值和每个mk对应返回值，整体返回值如下表，每个mk返回值(retValues[i].ver)succ为0，没数据为-6，有错为-1\
**参数：**
```
keys 主键集合
return 结果集合
```
```C++
//使用方法：
vector<string> vk;
vk.push_back("1123");
vk.push_back("1124");
auto retValues = DCacheOpt::getInstance()->getClient().getBatch<string>(vk);
cout << "getBatch return: " << retValues.getRet() << endl; 
for(size_t i = 0; i < vk.size() && i < retValues.size(); ++i) {
    cout << "mk: " << vk[i] << "|ret: " << retValues[i].ret << "|value: " << retValues[i].value
         << "|ver: " << (int)retValues[i].ver << "|expireTime: " << retValues[i].expireTime << endl;
}

//BatchKeyValues类型：
template<typename V>
struct BatchKeyValues
{
    BatchKeyValues()
    {

    }
    struct Items
    {
        Items() : ret(-1),ver(0),expireTime(0){}
        Items(taf::Int32 iRet) : ret(iRet),ver(0),expireTime(0){}
        Items(const V&v , taf::Int32 iRet,taf::Char cVer, taf::Int64 iExpire ) : value(v)
        {
            ret = iRet;
            ver = cVer;
            expireTime = iExpire;
        }
        V value;
        taf::Int32 ret;
        taf::Char ver;
        taf::Int64 expireTime;
    };
    size_t size() const
    {
        return values.size();
    }
    bool empty() const
    {
        return values.empty();
    }
    Items& operator[](size_t i) {
        return values[i];
    }
    int getRet() {
        return iRet;
    }
    typedef vector<Items> vContainer;
    typedef typename vContainer::iterator iterator;
    iterator begin() {
        return values.begin();
    }
    iterator end() {
        return values.end();
    }

    int iRet;
    vector<Items> values;
};
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 更新成功 | 0
 [↑返回标题↑](#header) 



# <a id="kv-del-API-N"></a> delString(API_N)
```C++
int delString(const K& mainKey)
```
**功能：** 删除del\
**参数：**
```
mainKey 主键
```


 
# <a id="kv-set-API-N"></a> set(API_N)
```C++
int setString(const K& mainKey, const string& val)
int setString(const K& mainKey, const string& val, int expireTimeSecond = 0)
int setStringWithVer(const K& mainKey, const string& val, taf::Char ver)
```
**功能：** 插入数据，不关心版本号/带版本号\
**参数：**\
**注意：** 这个版本号 version 范围是从 0 - 255 ， 如果 version == 0 表示不带版本号， 要带版本号时 version 可以取除 0 以外的其它数 也就是 1-255， 虽然 version 传入 256 或 257 也是可以的，但是内部的取值会是 0 - 255， 当传入 256时，相当于你往cache中 写入 version =1 
```
mainKey 主键
val 值
expireTimeSecond 过期时间，为相对时间(客户端传入的是相对时间，服务端存的是绝对时间(其值为当前时间加上传入的相对时间))
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_TOO_LONG | 字段大小超过限制 | -28
 ET_CACHE_ERR | 缓存错误 | -25
 ET_MEM_FULL | 内存满 | -21
 ET_DATA_VER_MISMATCH | 版本不一致 | -15
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 更新成功 | 0
 [↑返回标题↑](#header)
 
 
 
# <a id="kv-setbatch-API-N"></a> setBatch(API_N)
```C++
template<typename V>
int setBatch(const vector<K> &keys, const vector<V> &values, int expire_time = 0 , bool bNoResp = false)
```
**功能：** 批量插入数据\
**参数：**
```
keys 主键集合
values 值
expire_time 过期时间，为相对时间
```
```
使用方法：
vector<HUYA::LiveStatSummaryKey> keys;
HUYA::LiveStatSummaryKey tKey;
tKey.lLiveId = 123456;
keys.push_back(tKey);
tKey.lLiveId = 234567;
keys.push_back(tKey);

vector<HUYA::LiveStatSummary> values;
HUYA::LiveStatSummary  tValue;
tValue.iEndTime = 13234225;
values.push_back(tValue);
tValue.iEndTime = 13234111;
values.push_back(tValue);

int ret = -1;
ret = DCacheOpt::getInstance()->getClient().setBatch<HUYA::LiveStatSummary>(keys, values);
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_EXCEED_LIMIT | 输入参数超过限制错误 | -38
 ET_INPUT_PARAM_ERROR | 参数错误，例如key为空 | -12
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 更新成功 | 0
 [↑返回标题↑](#header)
 
 
 
# <a id="kv-update-API-N"></a> updateStringEx(API_N)
```C++
int updateString(const K& mainKey, const string& val, DCache::Op option, string &retValue,int expireTimeSecond = 0)
```
**功能：** 更新数据\
**参数：**
```
mainKey 主键
val 值
expireTimeSecond 过期时间，为相对时间
option 更新操作，支持ADD/ADD_INSERT/SUB/SUB_INSERT/PREPEND/APPEND
其中数字类型一般使用ADD/ADD_INSERT/SUB/SUB_INSERT,带INSERT为不存在则插入，string类型一般用PREPEND/APPEND
retValue 更新后的值
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_OP_ERR | op错误，只支持ADD/ADD_INSERT/SUB/SUB_INSERT | -31
 ET_PARAM_TOO_LONG | 字段大小超过限制 | -28
 ET_DB_ERR | 数据库读取错误 | -24
 ET_MEM_FULL | 内存满 | -21
 ET_DATA_VER_MISMATCH | 版本不一致 | -15
 ET_INPUT_PARAM_ERROR | 参数错误，例如key为空 | -12
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_NO_DATA | 数据不存在 | -6
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 更新成功 | 0
 CACHE_KEY_AREA_ERR | 当前key不属于本机服务，需要更新路由表重新访问 | 5
 [↑返回标题↑](#header)
 
 
 
# <a id="kv-get"></a> get
```C++
int get( const K &k, V &v )
int getWithVer( const K &k, V &v, int &iTimespan, taf::Int64 &lVersion )
```
**功能：** 获取值，不关心版本号/带版本号\
**参数：**
```
k 主键
v 结果
lVersion 版本号
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_NO_DATA | 数据不存在 | -6
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 更新成功 | 0
 [↑返回标题↑](#header)
 
 
  
# <a id="kv-getbatch"></a> getBatch
```C++
int getBatch( const vector<K> &vk, vector<V> &v )
```
**功能：** 批量获取值\
**参数：**
```
vk 主键集合
v 结果集合
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 更新成功 | 0
 [↑返回标题↑](#header)
 
 
 
# <a id="kv-scan"></a> Scan
```C++
int Scan(int offset, int size, std::map<K,V>& mpData, std::vector<K>& timeout, bool &isEnd)
```
**功能：** 根据指定的范围查询哈希表中的数据\
**参数：**
```
offset 游标位置，查询的起始位置
size 查询位置的数量，即查询范围为[offset,offset+size)
mpData 查询结果
timeout scan超时的主键的集合
isEnd 是否到达最终位置
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_INPUT_PARAM_ERROR | 参数错误，例如key为空 | -12
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 更新成功 | 0
 [↑返回标题↑](#header)
 
 
 
# <span id="kv-erase">erase</span>
```C++
int erase( const K &k)
```
**功能：** 删除非脏的数据\
**参数：**
```
k 主键
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_ERASE_DIRTY_ERR | 不能用于删除脏数据 | -35
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 更新成功 | 0
 CACHE_KEY_AREA_ERR | 当前key不属于本机服务，需要更新路由表重新访问 | 5
 [↑返回标题↑](#header)
 
 
 
# <a id="kv-set"></a> set
```C++
int set( const K &k , const V &v, int expire_time, bool bNoResp = false ,bool bDirty = true)
int setWithVer( const K &k, const V &v, taf::Int64 lVersion, int iExpireTime = 0, bool bNoResp = false,bool bDirty = true)
```
**功能：** 插入数据，不关心版本号/带版本号\
**参数：**
```
k 主键
v 值
expire_time 过期时间，为相对时间
bDirty 是否设置为脏数据，即是否回写db(存在db都应设为true)
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_TOO_LONG | 字段大小超过限制 | -28
 ET_CACHE_ERR | 缓存错误 | -25
 ET_MEM_FULL | 内存满 | -21
 ET_DATA_VER_MISMATCH | 版本不一致 | -15
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 更新成功 | 0
 [↑返回标题↑](#header)
 
 
 
# <a id="kv-setbatch"></a> setBatch
```C++
int setBatch( const  vector<K> &vKey, const vector<V> &vValue, int expire_time = 0 , bool bNoResp = false )
```
**功能：** 插入数据，不关心版本号\
**参数：**
```
vKey 主键集合
vValue 结果集合
expire_time 过期时间，为相对时间
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_EXCEED_LIMIT | 输入参数超过限制错误 | -38
 ET_INPUT_PARAM_ERROR | 参数错误，例如key为空 | -12
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 更新成功 | 0
 [↑返回标题↑](#header)
 
 
 
# <a id="kv-modify"></a> modify
```C++
int modify( const K &k, F &&f , int expire_time = 0, bool bDirty = true )
```
**功能：** 从缓存中get数据，修改数据后set回去\
**参数：**
```
k 主键
f 修改方法
expire_time 过期时间，为相对时间
bDirty 是否设置为脏数据，即是否回写db(存在db都应设为true)
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_TOO_LONG | 字段大小超过限制 | -28
 ET_CACHE_ERR | 缓存错误 | -25
 ET_MEM_FULL | 内存满 | -21
 ET_DATA_VER_MISMATCH | 版本不一致 | -15
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 更新成功 | 0
 [↑返回标题↑](#header)
 
 
 
# <a id="kv-drop"></a> drop
```C++
int drop( const K &k , bool bNoResp = false )
```
**功能：** 删除数据\
**参数：**
```
k 主键
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_DB_ERR | 数据库读取错误 | -24
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 更新成功 | 0
 CACHE_KEY_AREA_ERR | 当前key不属于本机服务，需要更新路由表重新访问 | 5
 [↑返回标题↑](#header)
 
 
 
# <a id="kv-dropbatch"></a> dropBatch
```C++
int dropBatch( const vector<K> &vk , bool bNoResp = false )
```
**功能：** 批量删除数据\
**参数：**
```
vk 主键集合
```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_DB_ERR | 数据库读取错误 | -24
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 更新成功 | 0
 [↑返回标题↑](#header)
 
 
 
# <a id="kv-update"></a> updateStringEx
```C++
int updateStringEx(const K& k, const V & v,taf::Bool dirty,taf::Int32 expireTimeSecond,DCache::Op option,V &retValue)
```
**功能：** 更新数据\
**参数：**
```
k 主键
v 值
dirty 是否设置为脏数据，即是否回写db(存在db都应设为true)
expireTimeSecond 过期时间，为相对时间，
option 更新操作，支持ADD/ADD_INSERT/SUB/SUB_INSERT/PREPEND/APPEND
其中数字类型一般使用ADD/ADD_INSERT/SUB/SUB_INSERT,带INSERT为不存在则插入，string类型一般用PREPEND/APPEND

```
**返回值**：
返回值字符串 | 含义 | 返回数值
------------------ | ----------------| ----------------
 ET_PARAM_OP_ERR | op错误，只支持ADD/ADD_INSERT/SUB/SUB_INSERT | -31
 ET_PARAM_TOO_LONG | 字段大小超过限制 | -28
 ET_DB_ERR | 数据库读取错误 | -24
 ET_MEM_FULL | 内存满 | -21
 ET_DATA_VER_MISMATCH | 版本不一致 | -15
 ET_INPUT_PARAM_ERROR | 参数错误，例如key为空 | -12
 ET_FORBID_OPT | 正在迁移，禁止操作 | -11
 ET_SERVER_TYPE_ERR | SLAVE状态下不提供接口服务 | -9
 ET_NO_DATA | 数据不存在 | -6
 ET_KEY_AREA_ERR	| 当前key不属于本机服务，需要更新路由表重新访问 | -4
 ET_MODULE_NAME_INVALID | 模块名错误 | -2
 ET_SYS_ERR	| 系统异常 | -1
 ET_SUCC | 更新成功 | 0
 CACHE_KEY_AREA_ERR | 当前key不属于本机服务，需要更新路由表重新访问 | 5
 [↑返回标题↑](#header)
 
