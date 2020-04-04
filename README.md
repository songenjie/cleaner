# cleaner 
1. append 
- prometheus 
- thanos (sidecar/store)
- ceph s3
- s3cmd 

# issues
大致分为四种种情况

1. block 重复问题  进程不断重启
2. chunks 在上传ceph 时候丢失 循环压缩报错，compact 功能停止相当于
3. Chunks 丢失 panic: runtime error: slice bounds out of range 进程不断重启
4. 压缩成功但是，downsample 没有工作
- Downsample 硬性要求之前理解错了，不是说40个小时前的数据才开始downsample 而是压缩后的一块，这个块的大小达到40H,才会开始一级压缩

# 功能
清理 promeheus down掉，thanos sidecar 将错误的prometheus block 信息，shipper到 ceph 对象存储，thanos store compact 压缩失败的问题

# 解决方案
清理
1. 删除较小的块
2. 删除上传不完整的块
3. 需要讨论确定一个合适的时间长度


