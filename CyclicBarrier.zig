const std = @import("std");

const expect = std.testing.expect;

pub const CyclicBarrier = struct {
    pub const Node = struct {
        status: i32=1,
        prev: ?*Node=null,
        resetEvent: std.ResetEvent,
    };
    
    rounds: u32 = 0,
    parties: u32,
    count: u32,
    broken: bool=false,
    link: ?*Node = null,
    mutex: std.Mutex=std.Mutex{},
    
    const Self = @This();

    pub fn init(parties: u32) Self {
        return Self {.parties = parties, .count=parties};
    }
    
    pub fn getParties(self: *const Self) u32 {
        return self.parties;
    }
    
    pub fn isBroken(self: *Self) bool {
        var lock = self.mutex.acquire();
        defer lock.release();
        return self.broken;
    }

    pub fn wait(self: *Self) !void {
        var lock = self.mutex.acquire();
        
        if(self.broken == true){
            lock.release();
            return error.BARRIER_BROEKN;
        }
        
        if(self.parties == 0){
            lock.release();
            return;
        }
        if(self.count <= 1){
            if(self.parties == 1){
                self.rounds +%= 1;
                lock.release();
                return;
            }
            self.reset_barrier();
            lock.release();
            return;
        }
        
        var node = Node{.status = 1, .resetEvent = std.ResetEvent.init()};
        defer node.resetEvent.deinit();
        
        self.add_waiter(&node);
        

        self.count -= 1;
        lock.release();
        node.resetEvent.wait();
        var val = @atomicLoad(i32, &node.status, .Acquire);
        if(val == 0){
            return;
        }
        if(val == 1){
            std.debug.print("unexpected wakeup\n", .{});
            unreachable;
        }
        if(val == 2){
            return error.BARRIER_BROEKN;
        }

    }


    pub fn timedWait(self: *Self, timeout: u64) !void {
        var lock = self.mutex.acquire();
        
        if(self.broken == true){
            lock.release();
            return error.BARRIER_BROEKN;
        }
        
        if(self.parties == 0){
            lock.release();
            return;
        }
        if(self.count <= 1){
            expect(self.count == 1);
            if(self.parties == 1){
                self.rounds +%= 1;
                lock.release();
                return;
            }
            self.reset_barrier();
            lock.release();
            return;
        }
        
        var node = Node{.status = 1, .resetEvent = std.ResetEvent.init()};
        defer node.resetEvent.deinit();
        
        self.add_waiter(&node);
        self.count -= 1;
        lock.release();

        var ret = node.resetEvent.timedWait(timeout);
        if(ret) |_| {
            if(node.status == 0){
                return;
            }
            if(node.status == 2){
                return error.BARRIER_BROEKN;
            }
            expect(node.status == 1);
        } else |err| {
            lock = self.mutex.acquire();
            defer lock.release();
            if(node.status == 0){
                return;
            }
            if(node.status == 2){
                return error.BARRIER_BROEKN;
            }
            expect(node.status == 1);
            self.break_barrier();
            return error.TimedOut;
        }
    }

    fn set_status_all(self: *Self, status: i32) void{
        expect(self.link != null);
        var node: ?*Node = self.link;
        
        while(node != null) {
            const cur = node.?;
            node = cur.prev;
            
            cur.prev = null;
            cur.status = status;
            cur.resetEvent.set();
        }
    }

    pub fn break_all(self: *Self) void {
        self.set_status_all(2);
    }
    
    pub fn wakeup_all(self: *Self) void {
        self.set_status_all(0);
    }
    
    fn add_waiter(self: *Self, node: *Node) void {
        if(self.link == null){
            self.link = node;
        } else {
            node.prev = self.link;
            self.link = node;
        }
    }

    fn reset_barrier(self: *Self) void {
        self.count = self.parties;
        self.rounds +%= 1;
        self.broken = false;
        self.wakeup_all();
        self.link = null;
    }
    
    fn break_barrier(self: *Self) void {
        self.count = self.parties;
        self.broken = true;
        self.break_all();
        self.link = null;
    }

};

