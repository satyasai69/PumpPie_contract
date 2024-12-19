import "@stdlib/deploy";
import "@stdlib/ownable";
import "../messages";
import "../Jetton/JettonCore";

/**
 * @title Pool
 * @author me
 * @notice  its a Pool and Router 
 */
struct JettonPool {
    balance: Int as coins;
    isActive: Bool;
}

struct PendingSell {
    jettonAddress: Address;
    sender: Address;
    amount: Int;
}


message WalletDataMessage {
    balance: Int;
    owner: Address;
    jetton: Address;
    jetton_wallet_code: Cell;
}

// Pool Contract to handle TON liquidity for multiple jettons
contract PoolCore with Deployable, Ownable {
    owner: Address;
    pools: map<Address, JettonPool>;  // Map of jetton address to pool info
    pendingSells: map<Address, PendingSell>;  // Map of sender address to pending sell request
    
    init() {
        self.owner = sender();
        self.pools = emptyMap();
        self.pendingSells = emptyMap();
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

     /**
 * @dev This is function to Buy Jetton 
 * @notice  This take jetton address and amount to Buy by using Ton
 */

 // 1.check Jetton pool exist or not
 // 2.check Jetton pool is active or not
 // 3. check how many Ton user sending  
 // 4.send message to Jetton contract to check price of jetton and mint tokens by price (user send Ton to Pool and pool send message to Jetton contract to check price and mint tokens by price )
 // 5.update pool balance after successful mint
    
    // Receive TON from buy operations
    receive(msg: PoolBuy) {
        let gas: Int = ton("0.1");  // Fixed gas amount
        let forward_gas: Int = ton("0.05"); // Amount to forward for Jetton operations
        
        let pool: JettonPool? = self.pools.get(msg.jettonAddress);
        require(pool != null && pool!!.isActive, "Pool for this jetton does not exist");

        // Verify that received value is sufficient
        require(context().value > gas + forward_gas, "Insufficient value sent");
        
        let sender_address: Address = sender();
        let purchase_amount: Int = context().value - gas - forward_gas;

        // Update pool balance first
        self.pools.set(msg.jettonAddress, JettonPool{
            balance: pool!!.balance + purchase_amount,
            isActive: true
        });

        // Send minimal gas to Jetton contract for minting
        send(SendParameters{
            to: msg.jettonAddress,
            value: forward_gas, // Only send enough for gas
            bounce: true,
            body: BuyTokens{
                resAddress: sender_address,
                tonAmount: purchase_amount // This is how much TON was deposited
            }.toCell(),
            mode: SendIgnoreErrors
        });
    }
    
   /**
 * @dev This is function to sell Jetton 
 * @notice  This take jetton address and amount to sell and return Ton
 */
 // 1.check Jetton pool exist or not
 // 2.check Jetton pool is active or not
 // 3. check user address holding jetton amount to sell
 // 4.check Jetton pool balance is sufficient or not
 // 5.send message to Jetton contract to burn tokens
 // 6.update pool balance after successful burn
 // 7.send TON to the user
 

    receive(msg: PoolSell) {
        let pool: JettonPool? = self.pools.get(msg.jettonAddress);
        require(pool != null && pool!!.isActive, "Pool for this jetton does not exist");

        // Get the sender's address
        let sender_address: Address = sender();
        
        // Store the pending sell request data
        self.pendingSells.set(sender_address, PendingSell{
            jettonAddress: msg.jettonAddress,
            sender: sender_address,
            amount: msg.amount
        });
        
        // 3. check user address holding jetton amount to sell
        let initCode: StateInit = initOf JettonWalletImp(sender_address, msg.jettonAddress);
        let walletAddress: Address = contractAddress(initCode);
        
        send(SendParameters{
            to: walletAddress,
            value: ton("0.1"),
            bounce: true,
            mode: SendRemainingValue,
            body: "get_wallet_data".asComment()
        });


    }
    
   receive(msg: WalletDataMessage) {
        // Store the pending sell request data
        let pendingSell: PendingSell? = self.pendingSells.get(sender());
        require(pendingSell != null, "No pending sell request");
        
        // Verify user has enough balance
        require(msg.balance >= pendingSell!!.amount, "Insufficient Jetton balance");
        
        // Continue with sell operation
        self._processSell(pendingSell!!);
    } 
    
    fun _processSell(sell: PendingSell) {
        // Send message to Jetton contract to burn tokens
        send(SendParameters{
            to: sell.jettonAddress,
            value: 0,
            body: SellTokens{
                resAddress: sell.sender,
                tokenAmount: sell.amount
            }.toCell(),
            mode: SendIgnoreErrors
        });
        
        // Update pool balance
        let pool: JettonPool? = self.pools.get(sell.jettonAddress);
        require(pool != null && pool!!.isActive, "Pool for this jetton does not exist");
        
        self.pools.set(sell.jettonAddress, JettonPool{
            balance: pool!!.balance - sell.amount,
            isActive: true
        });

        // Send TON to the user
        send(SendParameters{
            to: sell.sender,
            value: sell.amount,
            mode: SendIgnoreErrors
        });
        
        // Clear pending sell
        self.pendingSells.set(sell.sender, null);
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
