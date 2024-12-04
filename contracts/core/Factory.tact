import "@stdlib/deploy";
import "@stdlib/ownable";
import "./Pool";

message DeployPool {
    tokenAddress: Address;
}

contract Factory with Deployable, Ownable {
    owner: Address;
    pools: map<Address, Address>; // tokenAddress -> poolAddress
    totalPools: Int;

    init() {
        self.owner = sender();
        self.totalPools = 0;
    }

    receive(msg: DeployPool) {
        // Check if enough TON is sent for deployment fee
        require(context().value >= ton("1.3"), "Must send at least 1.3 TON");
        
        // Check if pool already exists for this token
        let existingPool: Address? = self.pools.get(msg.tokenAddress);
        require(existingPool == null, "Pool already exists for this token");

        // Send 1 TON to owner as fee
        send(SendParameters{
            to: self.owner,
            value: ton("1"),
            mode: SendIgnoreValue,
            body: "Pool deployment fee".asComment()
        });

        // Create Pool contract initialization
        let init: StateInit = initOf Pool(msg.tokenAddress);
        let poolAddress: Address = contractAddress(init);

        // Deploy the Pool contract with remaining TON
        send(SendParameters{
            to: poolAddress,
            value: ton("0.2"), // Send enough TON for deployment and initial storage
            mode: SendIgnoreErrors,
            code: init.code,
            data: init.data,
            body: "Pool deployed".asComment()
        });

        // Store the pool address
        self.pools.set(msg.tokenAddress, poolAddress);
        self.totalPools = self.totalPools + 1;
    }

    // Getter to retrieve pool address for a token
    get fun getPool(tokenAddress: Address): Address? {
        return self.pools.get(tokenAddress);
    }

    // Getter for total number of pools
    get fun getTotalPools(): Int {
        return self.totalPools;
    }
}
