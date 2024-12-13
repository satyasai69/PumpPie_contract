import "@stdlib/deploy";
import "@stdlib/ownable";
import "../messages";

struct JettonPool {
    balance: Int as coins;
    isActive: Bool;
}

// Pool Contract to handle TON liquidity for multiple jettons
contract PoolCore with Deployable, Ownable {
    owner: Address;
    pools: map<Address, JettonPool>;  // Map of jetton address to pool info
    
    init() {
        self.owner = sender();
        self.pools = emptyMap();
    }
    
    // Add new jetton to the pool
    receive(msg: AddJetton) {
        require(sender() == self.owner, "Only owner can add jettons");
        let currentPool: JettonPool? = self.pools.get(msg.jettonAddress);
        if (currentPool != null) {
            require(!currentPool!!.isActive, "Jetton already exists");
        }
        
        // Initialize new pool for the jetton
        self.pools.set(msg.jettonAddress, JettonPool{
            balance: 0,
            isActive: true
        });
    }
    
    // Receive TON from buy operations
    receive(msg: PoolBuy) {


        let pool: JettonPool? = self.pools.get(msg.jettonAddress);
        require(pool != null && pool!!.isActive, "Pool for this jetton does not exist");

     // Verify that received value is sufficient
    require(context().value >= msg.amount, "Insufficient value sent");
        
        // Update pool balance
        self.pools.set(msg.jettonAddress, JettonPool{
            balance: pool!!.balance + msg.amount,
            isActive: true
        });
    }
    
    // Send TON for sell operations
    receive(msg: PoolSell) {
        let pool: JettonPool? = self.pools.get(msg.jettonAddress);
        require(pool != null && pool!!.isActive, "Pool for this jetton does not exist");
        require(msg.amount <= pool!!.balance, "Insufficient liquidity in pool");
        
        // Send TON to the specified address
        send(SendParameters{
            to: msg.to,
            value: msg.amount,
            bounce: true
        });
        
        // Update pool balance
        self.pools.set(msg.jettonAddress, JettonPool{
            balance: pool!!.balance - msg.amount,
            isActive: true
        });
    }
    
    // Get pool liquidity for a specific jetton
    get fun getJettonLiquidity(jettonAddress: Address): Int {
        let pool: JettonPool? = self.pools.get(jettonAddress);
        require(pool != null && pool!!.isActive, "Pool for this jetton does not exist");
        return pool!!.balance;
    }
    
    // Check if pool exists for a jetton
    get fun hasPool(jettonAddress: Address): Bool {
        let pool: JettonPool? = self.pools.get(jettonAddress);
        return (pool != null) && pool!!.isActive;
    }
    
    // Remove jetton pool (only owner)
    fun removeJettonPool(jettonAddress: Address) {
        require(sender() == self.owner, "Only owner can remove pools");
        let pool: JettonPool? = self.pools.get(jettonAddress);
        require(pool != null && pool!!.isActive, "Pool does not exist");
        require(pool!!.balance == 0, "Pool must be empty to remove");
        
        // Deactivate pool
        self.pools.set(jettonAddress, JettonPool{
            balance: pool!!.balance,
            isActive: false
        });
    }
    
    // Withdraw TON from specific pool (only owner)
    fun withdrawFromPool(jettonAddress: Address, amount: Int) {
        require(sender() == self.owner, "Only owner can withdraw");
        let pool: JettonPool? = self.pools.get(jettonAddress);
        require(pool != null && pool!!.isActive, "Pool does not exist");
        require(amount <= pool!!.balance, "Insufficient balance");
        
        send(SendParameters{
            to: self.owner,
            value: amount,
            bounce: true
        });
        
        self.pools.set(jettonAddress, JettonPool{
            balance: pool!!.balance - amount,
            isActive: true
        });
    }
}
