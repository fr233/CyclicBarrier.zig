const std = @import("std");

const CyclicBarrier = @import("./CyclicBarrier.zig").CyclicBarrier;


const Param = struct {
    id: usize,
    barrier: *CyclicBarrier,
};

var end: usize = 0;

fn barrier_test(param: Param) !void {
    var id = param.id;
    var r= param.barrier.wait();

    while(end == 0){
        
        var round = @atomicLoad(u32, &param.barrier.rounds, .SeqCst);
        
        var ret = param.barrier.timedWait(10000000, id);
        //var ret = param.barrier.wait();
        if(ret) |_| {
            std.debug.print("{}\t{}\tnot timeout\n", .{id, round});
        } else |err| {
            std.debug.print("{}\t{}\t{}\n", .{id, round, err});
            return;
        }
        std.time.sleep(1000000000);
    }

}

var end:u32 = 0;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    
    var threads:[8]*std.Thread = undefined;

    var barrier = CyclicBarrier.init(8);
    var param = Param{.id=0, .barrier=&barrier};
    for(threads[0..8]) |*item|{
        item.* = std.Thread.spawn(param, barrier_test) catch unreachable;
        param.id+=1;
    }
    std.time.sleep(5000000000);
    end = 1;

    for(threads)|item, idx|{
        item.wait();
    }
    std.debug.print("broken:? {}\n", .{barrier.isBroken()});
}