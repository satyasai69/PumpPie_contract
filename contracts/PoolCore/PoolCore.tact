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

message DeployJetton {
    owner: Address;
    content: Cell;
    max_supply: Int;
    token_price: Int;
    initial_mint: Int;
    pool: Address;
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
        let gas: Int = ton("0.1");  // Fixed gas amount
        let forward_gas: Int = ton("0.05"); // Amount to forward for Jetton operations
        
        // Verify that received value is sufficient
        require(context().value > gas + forward_gas, "Insufficient value sent");
        
        // Get the sender's address
        let sender_address: Address = sender();
        
        // Verify pool exists and is active
        let pool: JettonPool? = self.pools.get(msg.jettonAddress);
        require(pool != null && pool!!.isActive, "Pool for this jetton does not exist");

        // Send SellTokens message to JettonCore
        send(SendParameters{
            to: msg.jettonAddress,
            value: forward_gas,
            bounce: true,
            body: SellTokens{
                resAddress: sender(),//msg.to,
                tokenAmount: msg.amount
            }.toCell(),
            mode: SendIgnoreErrors
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
    
    // Deploy a new Jetton contract
    receive(msg: DeployJetton) {
        // Verify sufficient gas for deployment
        let gas: Int = ton("0.1");  // Fixed gas amount
        let forward_gas: Int = ton("0.05"); // Amount to forward for Jetton operations
        require(context().value > gas + forward_gas, "Insufficient value sent for deployment");

        // Deploy new Jetton contract
        let stateInit: StateInit = initOf JettonCore(
            msg.owner,
            msg.content,
            msg.max_supply,
            msg.token_price,
            msg.initial_mint,
            msg.pool
        );

        // Send deployment message
        send(SendParameters{
            to: contractAddress(stateInit),
            value: forward_gas,
            bounce: true,
            mode: SendRemainingValue,
            code: stateInit.code,
            data: stateInit.data
        });

        // Add the new Jetton to the pool
        let jettonAddress: Address = contractAddress(stateInit);
        self.pools.set(jettonAddress, JettonPool{
            balance: 0,
            isActive: true
        });
    }

    fun getJettonInit(owner: Address, content: Cell, max_supply: Int, token_price: Int, initial_mint: Int, pool: Address): StateInit {
        return initOf JettonCore(
            owner,      // owner
            content,    // content
            max_supply, // max_supply
            token_price, // token_price
            initial_mint, // initial_mint
            pool        // pool address
        );
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
    
    // Get Jetton address for a given pool
    get fun getJettonAddress(owner: Address): Address {
        let init: StateInit = self.getJettonInit(
            owner,      // owner
            beginCell().endCell(), // empty content for address calculation
            0,         // max_supply (not needed for address)
            0,         // token_price (not needed for address)
            0,         // initial_mint (not needed for address)
            myAddress() // pool
        );
        return contractAddress(init);
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

    receive(msg: WithdrawFromPool) {
        // Only owner can withdraw
        require(sender() == self.owner, "Only owner can withdraw");
        
        // Get pool info
        let pool: JettonPool? = self.pools.get(msg.jettonAddress);
        require(pool != null && pool!!.isActive, "Pool does not exist");
        
        // Verify sufficient balance
        require(pool!!.balance >= msg.amount, "Insufficient pool balance");
        
        // Calculate gas requirements
        let forward_amount: Int = msg.amount;
        let remain_value: Int = context().value;
        require(remain_value >= ton("0.05"), "Insufficient gas for withdrawal");
        
        // Update pool balance
        self.pools.set(msg.jettonAddress, JettonPool{
            balance: pool!!.balance - msg.amount,
            isActive: true
        });
        
        // Send TON to owner
        send(SendParameters{
            to: self.owner,
            value: forward_amount,
            bounce: false,
            mode: SendIgnoreErrors
        });
    }

    receive("withdrawAllTon") {
        // Only owner can withdraw
        require(sender() == self.owner, "Only owner can withdraw");
        
        // Calculate amount to withdraw (leave some for gas)
        let amount: Int = myBalance() - ton("0.1");
        
        // Send all TON to owner
        if (amount > 0) {
            send(SendParameters{
                to: self.owner,
                value: amount,
                bounce: false,
                mode: SendRemainingValue + SendIgnoreErrors
            });
        }
    }

    receive("withdraw_all") {
        // Only owner can withdraw all
        require(sender() == self.owner, "Only owner can withdraw");
        
        // Calculate gas requirements
        let remain_value: Int = context().value;
        require(remain_value >= ton("0.05"), "Insufficient gas for withdrawal");
        
        // Calculate total balance across all pools
        let total: Int = 0;
        let pools_map: map<Address, JettonPool> = self.pools;
        
        // Get all pool balances
        let keys: map<Address, Bool> = emptyMap();
        let addr: Address = beginCell().endCell().asSlice().loadAddress();
        let pool: JettonPool? = self.pools.get(addr);
        
        while (pool != null) {
            if (pool!!.isActive) {
                total = total + pool!!.balance;
                // Reset pool balance
                self.pools.set(addr, JettonPool{
                    balance: 0,
                    isActive: true
                });
            }
            addr = beginCell().endCell().asSlice().loadAddress();
            pool = self.pools.get(addr);
        }
        
        // Send all TON to owner
        if (total > 0) {
            send(SendParameters{
                to: self.owner,
                value: total,
                bounce: false,
                mode: SendIgnoreErrors,
                body: "Withdrawn all pool balances".asComment()
            });
        }
    }

    receive(msg: BurnNotificationWithTon) {
        // Verify sender is a known Jetton contract
        let pool: JettonPool? = self.pools.get(sender());
        require(pool != null && pool!!.isActive, "Unknown Jetton contract");
        
        // Verify pool has enough balance
        require(pool!!.balance >= msg.amount, "Insufficient pool balance");
        
        // Calculate gas requirements
        let forward_amount: Int = msg.amount;
        let remain_value: Int = context().value;
        require(remain_value >= forward_amount, "Insufficient value for transfer");
        
        // Update pool balance
        self.pools.set(sender(), JettonPool{
            balance: pool!!.balance - msg.amount,
            isActive: true
        });
        
        // Send TON to user
        send(SendParameters{
            to: msg.user,
            value: forward_amount,
            bounce: false,
            mode: SendIgnoreErrors
        });
        
        // Return any excess gas
        if (remain_value - forward_amount > 0) {
            send(SendParameters{
                to: sender(),
                value: remain_value - forward_amount,
                bounce: false,
                mode: SendIgnoreErrors
            });
        }
    }
}
