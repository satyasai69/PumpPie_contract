import "@stdlib/deploy";
import "@stdlib/ownable";
import "./Pool";

message DeployPool {
    tokenAddress: Address;  // Address of the token to create pool for
}

/*message TransferOwnership {
    newOwner: Address;
}*/

contract Factory with Deployable, Ownable {
    owner: Address;
    pools: map<Address, Address>;
    totalPools: Int as uint32;
    
    init() {
        self.owner = sender();
        self.totalPools = 0;
    }
    
    receive(msg: DeployPool) {
        // Ensure minimum TON for deployment and fees
        require(context().value >= ton("1.1"), "Insufficient TON for deployment");
        
        // Check if pool already exists
        let existing: Address? = self.pools.get(msg.tokenAddress);
        require(existing == null, "Pool already exists for this token");
        
        // Deploy new pool
       // let pool: StateInit = Pool.init(msg.tokenAddress); //myAddress()
     //  let poolAddress: Address = contractAddress(pool);

         let init: StateInit = initOf Pool(msg.tokenAddress);
        let poolAddress: Address = contractAddress(init);
        
        // Store pool address
        //self.pools.set(msg.tokenAddress, poolAddress);
  // self.init.set(msg.tokenAddress, poolAddress);
    //    self.totalPools = self.totalPools + 1;


                // Store the pool address
        self.pools.set(msg.tokenAddress, poolAddress);
        self.totalPools = self.totalPools + 1;
        
        // Deploy pool contract
        send(SendParameters{
            to: poolAddress,
            value: ton("1"),
            mode: SendIgnoreErrors,
            code: init.code,
            data: init.data,
            body: Deploy{
                queryId: 0
            }.toCell()
        });

        // Transfer token ownership to pool
        send(SendParameters{
            to: msg.tokenAddress,
            value: ton("0.05"),
            mode: SendIgnoreErrors,
            body: TransferOwnership{
                newOwner: poolAddress
            }.toCell()
        });
        
        // Send remaining TON to owner as fee
        send(SendParameters{
            to: self.owner,
            value: ton("0.05"),
            mode: SendRemainingValue + SendIgnoreErrors
        });
    }
    
    // Get pool address for a token
    get fun getPool(tokenAddress: Address): Address? {
        return self.pools.get(tokenAddress);
    }
    
    // Get total number of pools
    get fun getTotalPools(): Int {
        return self.totalPools;
    }
}
