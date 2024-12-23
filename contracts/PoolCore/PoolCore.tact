import "@stdlib/deploy";
import "@stdlib/ownable";
import "../messages";
import "../Jetton/JettonCore";

// Interface for interacting with Jetton contracts
// trait Jetton {
//     abstract fun getJettonName(): String;
//     abstract fun getJettonSymbol(): String;
// }

struct JettonPool {
    balance: Int as coins;
    isActive: Bool;
}

struct PendingSell {
    jettonAddress: Address;
    sender: Address;
    amount: Int;
}

struct JettonPoolInfo {
    balance: Int as coins;
    name: String;
    symbol: String;
    holdersCount: Int;
    volume24h: Int as coins;
    volume1h: Int as coins;
    volume6h: Int as coins;
}

struct VolumeData {
    volume: Int as coins;
    timestamp: Int as uint32;
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

message UpdateVolume {
    jettonAddress: Address;
    amount: Int as coins;
}

// Pool Contract to handle TON liquidity for multiple jettons
contract PoolCore with Deployable, Ownable {
    owner: Address;
    pools: map<Address, JettonPool>;  // Map of jetton address to pool info
    pendingSells: map<Address, PendingSell>;  // Map of sender address to pending sell request
    holdersCount: map<Address, Int>;
    volumes24h: map<Address, VolumeData>;
    volumes1h: map<Address, VolumeData>;
    volumes6h: map<Address, VolumeData>;
    
    init() {
        self.owner = sender();
        self.pools = emptyMap();
        self.pendingSells = emptyMap();
        self.holdersCount = emptyMap();
        self.volumes24h = emptyMap();
        self.volumes1h = emptyMap();
        self.volumes6h = emptyMap();
    }
    
    // Add new jetton to the pool
    receive(msg: AddJetton) {
     //   require(sender() == self.owner, "Only owner can add jettons");
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

        // Check if balance crossed 69 TON threshold and list on DeDust if needed
        self.checkAndListOnDeDust(msg.jettonAddress);

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
            bounce: false,
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
    
    // Get pool information for a specific jetton
    get fun getPoolInfo(jettonAddress: Address): JettonPoolInfo {
        let pool: JettonPool = self.pools.get(jettonAddress)!!;
        
        let holdersCount: Int? = self.holdersCount.get(jettonAddress);
        let actualHoldersCount: Int = 0;
        if (holdersCount != null) {
            actualHoldersCount = holdersCount!!;
        }
        
        // Get volume data
        let vol24h: VolumeData? = self.volumes24h.get(jettonAddress);
        let vol1h: VolumeData? = self.volumes1h.get(jettonAddress);
        let vol6h: VolumeData? = self.volumes6h.get(jettonAddress);
        
        let currentTime: Int = now();
        
        // Reset volumes if time period has passed
        let volume24h: Int = 0;
        let volume1h: Int = 0;
        let volume6h: Int = 0;
        
        if (vol24h != null) {
            if (currentTime - vol24h!!.timestamp <= 86400) {
                volume24h = vol24h!!.volume;
            }
        }
        
        if (vol1h != null) {
            if (currentTime - vol1h!!.timestamp <= 3600) {
                volume1h = vol1h!!.volume;
            }
        }
        
        if (vol6h != null) {
            if (currentTime - vol6h!!.timestamp <= 21600) {
                volume6h = vol6h!!.volume;
            }
        }
        
        return JettonPoolInfo{
            balance: pool.balance,
            name: "Jetton",  // For now, we'll use static values since we can't safely call external contracts
            symbol: "JTN",   // in a getter function
            holdersCount: actualHoldersCount,
            volume24h: volume24h,
            volume1h: volume1h,
            volume6h: volume6h
        };
    }

    // Update volume data
    receive(msg: UpdateVolume) {
        let currentTime: Int = now();
        
        // Update 1h volume
        let vol1h: VolumeData? = self.volumes1h.get(msg.jettonAddress);
        if (vol1h == null || currentTime - vol1h!!.timestamp > 3600) {
            self.volumes1h.set(msg.jettonAddress, VolumeData{volume: msg.amount, timestamp: currentTime});
        } else {
            self.volumes1h.set(msg.jettonAddress, VolumeData{
                volume: vol1h!!.volume + msg.amount,
                timestamp: vol1h!!.timestamp
            });
        }

        // Update 6h volume
        let vol6h: VolumeData? = self.volumes6h.get(msg.jettonAddress);
        if (vol6h == null || currentTime - vol6h!!.timestamp > 21600) {
            self.volumes6h.set(msg.jettonAddress, VolumeData{volume: msg.amount, timestamp: currentTime});
        } else {
            self.volumes6h.set(msg.jettonAddress, VolumeData{
                volume: vol6h!!.volume + msg.amount,
                timestamp: vol6h!!.timestamp
            });
        }

        // Update 24h volume
        let vol24h: VolumeData? = self.volumes24h.get(msg.jettonAddress);
        if (vol24h == null || currentTime - vol24h!!.timestamp > 86400) {
            self.volumes24h.set(msg.jettonAddress, VolumeData{volume: msg.amount, timestamp: currentTime});
        } else {
            self.volumes24h.set(msg.jettonAddress, VolumeData{
                volume: vol24h!!.volume + msg.amount,
                timestamp: vol24h!!.timestamp
            });
        }
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
    
    // Get all pool addresses
    get fun getAllPools(): map<Address, JettonPool> {
        return self.pools;
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
        // Get the pool info
        let jettonAddress: Address = sender();
        let pool: JettonPool? = self.pools.get(jettonAddress);
        require(pool != null && pool!!.isActive, "Pool for this jetton does not exist");
        
        // Update pool balance
        let newBalance: Int = pool!!.balance - msg.amount;
        require(newBalance >= 0, "Insufficient pool balance");
        
        self.pools.set(jettonAddress, JettonPool{
            balance: newBalance,
            isActive: true
        });
        
        // Send TON to user
        send(SendParameters{
            to: msg.user,
            value: msg.amount,
            bounce: false,
            mode: SendIgnoreErrors
        });
    }

    /**
     * @dev Check pool balance and list on DeDust if it crosses 69 TON
     * @notice Automatically lists the token on DeDust when pool balance crosses 69 TON
     * @param jettonAddress The address of the jetton to check
     */
    fun checkAndListOnDeDust(jettonAddress: Address) {
        let pool: JettonPool? = self.pools.get(jettonAddress);
        require(pool != null && pool!!.isActive, "Pool for this jetton does not exist");
        
        // Check if pool balance crosses 69 TON
        if (pool!!.balance >= ton("69")) {
            // Send message to DeDust for listing
            send(SendParameters{
                to: jettonAddress,  // This should be DeDust contract address in production
                value: ton("0.1"),  // Gas for listing
                bounce: true,
                body: ListOnDeDust{
                    jettonAddress: jettonAddress
                }.toCell(),
                mode: SendIgnoreErrors
            });
        }
    }

    /**
     * @dev Check if a jetton's pool balance is sufficient for DeDust listing
     * @notice Checks if pool balance crosses 69 TON for listing on DeDust
     * @param jettonAddress The address of the jetton to check
     * @return Bool Returns true if pool balance is >= 69 TON, false otherwise
     */
    get fun checkPoolBalanceForDeDust(jettonAddress: Address): Bool {
        let pool: JettonPool? = self.pools.get(jettonAddress);
        require(pool != null && pool!!.isActive, "Pool for this jetton does not exist");
        
        // Check if pool balance is >= 69 TON
        return pool!!.balance >= ton("69");
    }
}
