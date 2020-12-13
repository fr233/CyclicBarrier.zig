# CyclicBarrier.zig
CyclicBarrier for zig lang

# how to use
```
const CyclicBarrier = @import("./CyclicBarrier.zig").CyclicBarrier;

main thread:
pub fn main() !void {
    ....
    var barrier = CyclicBarrier.init(8); // the number of 'parties'
    var param = Param{.barrier=&barrier};
    var threads:[8]*std.Thread = undefined;
    for(threads[0..8]) |*item|{
        item.* = std.Thread.spawn(param, barrier_test) catch unreachable;
    }
    ....
}

worker threads:
fn barrier_test(param: Param) !void {
  while(true){
    doSomeThing();
    param.barrier.wait();  //wait all participants to complete their jobs
    //var ret = param.barrier.timedWait(100000000); // or you can use timedWait()
    gotoNextPhrase();
  }
}


```
