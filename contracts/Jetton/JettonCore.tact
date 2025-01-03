import "@stdlib/deploy";
import "./traits/JettonMaster.tact";
import "./traits/JettonWallet.tact";
import "../messages"; 

message TransferOwnership {
    //  queryId: Int as uint64;  // Added standard queryId
    newOwner: Address;
}

/* message BuyTokens {
    tokenAmount: Int;
}

message SellTokens {
    tokenAmount: Int;
} */

/*message JettonMint {
    receiver: Address;
    amount: Int;
    origin: Address;
} */

contract JettonCore with JettonMaster, Deployable {
    total_supply: Int as coins;
    owner: Address;
    jetton_content: Cell;
    mintable: Bool;
    max_supply: Int as coins;
    initial_mint_amount: Int as coins;
    initial_token_price: Int as coins;
    curve_steepness: Int;
    base_amount: Int as coins;
    pool: Address;  // Address of the Pool contract

    init(owner: Address, content: Cell, max_supply: Int, token_price: Int, initial_mint: Int, pool: Address){
        require(max_supply > 0, "Max supply must be greater than 0");
        require(token_price > 0, "Token price must be greater than 0");
        require(initial_mint >= 0 && initial_mint <= max_supply, "Invalid initial mint amount");
        
       self.total_supply = 0;
        self.owner = owner;
        self.mintable = true;
        self.jetton_content = content;
        self.max_supply = max_supply;
        self.initial_token_price = token_price;
        self.curve_steepness = 1;  // Default value, can be adjusted
        self.base_amount = 1000000000;  // 1 TON as base, can be adjusted
        self.pool = pool;
        self.initial_mint_amount = initial_mint;

        // Mint initial tokens to owner if specified
        if (initial_mint > 0) {
            self._mint(context(), JettonMint{
                origin: owner,
                receiver: owner,
                amount: initial_mint,
                custom_payload: null,
                forward_ton_amount: 0,
                forward_payload: emptySlice()
            });
        } 
    } 

     
    


   

    override fun _mint_validate(ctx: Context, msg: JettonMint) {
        require(ctx.sender == self.owner, "Only owner can mint");
        require(self.mintable, "Minting is disabled");
        require(msg.amount > 0, "Invalid mint amount");
        require(self.total_supply + msg.amount <= self.max_supply, "Exceeds max supply");
    }

    override  fun _mint(ctx: Context, msg: JettonMint) {
        let initCode: StateInit = self.calculate_jetton_wallet_init(msg.receiver);
        self.total_supply = self.total_supply + msg.amount;
        
        send(SendParameters{
            to: contractAddress(initCode),
            value: 0,
            bounce: true,
            mode: SendRemainingValue,
            body: JettonInternalTransfer{
                query_id: 0,
                amount: msg.amount,
                response_address: msg.origin,
                from: myAddress(),
                forward_ton_amount: msg.forward_ton_amount,
                forward_payload: msg.forward_payload
            }.toCell(),
            code: initCode.code,
            data: initCode.data
        });
    }


    override fun _burn_notification(ctx: Context, msg: JettonBurnNotification) {
        // Validate burn notification
        self._burn_notification_validate(ctx, msg);
        
        // Update total supply
        self.total_supply = self.total_supply - msg.amount;
        
        // Calculate TON amount to return based on current price
        let price: Int = self.getCurrentPrice();
        let tonAmount: Int = (msg.amount * price) / 1000000000;
        
        // Forward remaining gas to pool for TON transfer
        let msgValue: Int = min(context().value, ton("0.1"));
        
        // Send notification to pool for TON transfer
        send(SendParameters{
            to: self.pool,
            value: msgValue,
            bounce: true,
            mode: SendIgnoreErrors,
            body: BurnNotificationWithTon{
                amount: tonAmount,
                tokenAmount: msg.amount,
                user: msg.response_destination
            }.toCell()
        });

        // Send any excess value back to user
        if (context().value - msgValue > 0) {
            send(SendParameters{
                to: msg.response_destination,
                value: context().value - msgValue,
                bounce: false,
                mode: SendIgnoreErrors
            });
        }
    }

    override fun _burn_notification_validate(ctx: Context, msg: JettonBurnNotification) {
        let initCode: StateInit = self.calculate_jetton_wallet_init(msg.sender);
        let isValidWallet: Bool = ctx.sender == contractAddress(initCode);
        require(ctx.sender == self.pool || isValidWallet, "Invalid sender: must be pool or valid wallet");
        require(msg.amount > 0, "Amount must be greater than 0");
        require(self.total_supply >= msg.amount, "Insufficient tokens to burn");
    }

    override inline fun calculate_jetton_wallet_init(owner_address: Address): StateInit {
        return initOf JettonWalletImp(owner_address, myAddress());
    }

    // Price in Ton
   //Price = Initial Price * (1 + Purchase Amount / 0)^Curve Steepness
    // Calculate price for a specific purchase amount
    get fun getPriceForAmount(purchase_amount: Int): Int {
        require(purchase_amount > 0, "Purchase amount must be greater than 0");
        require(self.total_supply + purchase_amount <= self.max_supply, "Purchase would exceed max supply");
        
        let supply_ratio: Int = (purchase_amount * 1000000000) / self.base_amount;  // Multiply by 10^9 for precision
        
        // Return total price (initial_price * amount) if supply ratio is zero
        if (supply_ratio == 0) {
            return self.initial_token_price * purchase_amount;
        }
        
        let base_multiplier: Int = 1000000000 + supply_ratio;  // (1 + Purchase Amount / Base)
        
        // Calculate power: base_multiplier^curve_steepness
        let result: Int = self.initial_token_price;
        repeat(self.curve_steepness) {
            result = (result * base_multiplier) / 1000000000;  // Divide by 10^9 to maintain scale
        }
        
        return result;
    }

    // Calculate total cost for purchasing a specific amount
    get fun getTotalCostForAmount(purchase_amount: Int): Int {
        require(purchase_amount > 0, "Purchase amount must be greater than 0");
        require(self.total_supply + purchase_amount <= self.max_supply, "Purchase would exceed max supply");
        
        let price: Int = self.getPriceForAmount(purchase_amount);
        return price * purchase_amount;
    }

    // Calculate current token price based on bonding curve
    get fun getCurrentPrice(): Int {
        let supply_ratio: Int = (self.total_supply * 1000000000) / self.base_amount;  // Multiply by 10^9 for precision
        
        // Return initial price if supply ratio is zero
        if (supply_ratio == 0) {
            return self.initial_token_price;
        }
        
        let base_multiplier: Int = 1000000000 + supply_ratio;  // (1 + Purchase Amount / Base)
        
        // Calculate power: base_multiplier^curve_steepness
        let result: Int = self.initial_token_price;
        repeat(self.curve_steepness) {
            result = (result * base_multiplier) / 1000000000;  // Divide by 10^9 to maintain scale
        }
        
        return result;
    }


    get fun getCurrentPrice2(): Int {
    // Ensure no division by zero
    if (self.base_amount == 0 || self.total_supply == 0) {
        throw(101);
    }
    
    // Calculate the supply ratio with precision
    let supply_ratio: Int = (self.total_supply * 1000000000) / self.base_amount;
    let base_multiplier: Int = 1000000000 + supply_ratio;  // Precision multiplier

    // Initialize result with the initial token price
    let result: Int = self.initial_token_price;

    // Check for reasonable curve steepness
    if (self.curve_steepness <= 0 || self.curve_steepness > 100) {
        throw(102);
    }

    return result;
}

// Function to get total supply in coins
get fun getTotalSupplyInCoins(): Int {
    // Convert total supply from atomic units to coins
    let total_supply_in_coins: Int = self.total_supply / 1000000000;
    return total_supply_in_coins;
}

  receive(msg: BuyTokens) {


    // Verify sender is the pool
   // require(sender() == self.pool, "Only pool can initiate buy");
    // Set pool as owner temporarily for minting
    self.owner = sender();
    self.mintable = true;
    
    // Calculate tokens to mint based on the bonding curve
    let price: Int = self.getCurrentPrice();
    require(price > 0, "Invalid token price");
    
    // Calculate tokens to mint
    let tokensToMint: Int = (msg.tonAmount * 1000000000) / price;
    require(tokensToMint > 0, "Amount too small to mint tokens");
    require(self.total_supply + tokensToMint <= self.max_supply, "Would exceed max supply");
    
    // Mint tokens to the buyer using JettonMint
    self._mint(context(), JettonMint{
        origin: myAddress(),
        receiver: msg.resAddress,
        amount: tokensToMint,
        custom_payload: null,
        forward_ton_amount: 0,
        forward_payload: emptySlice()
    });
    
    // Update total supply
    // self.total_supply = self.total_supply + tokensToMint;
  }

    receive(msg: SellTokens) {
        require(msg.tokenAmount > 0, "Amount must be greater than 0");
        
        // Get the sender's wallet address
        let senderWalletAddress: Address = self.get_wallet_address(msg.resAddress);
        
        // Create StateInit for the sender's wallet to verify
        let initCode: StateInit = self.calculate_jetton_wallet_init(msg.resAddress);
        require(contractAddress(initCode) == senderWalletAddress, "Invalid wallet address");

        // Send message to wallet to burn tokens
        send(SendParameters{
            to: senderWalletAddress,
            value: 0,
            mode: SendRemainingValue,
            bounce: true,
            body: JettonBurn{
                query_id: 0,
                amount: msg.tokenAmount,
                response_destination: msg.resAddress,
                custom_payload: null
            }.toCell()
        });
    }
    receive("Mint:Close"){
        let ctx: Context = context();
        require(ctx.sender == self.owner, "JettonMaster: Sender is not a Jetton owner");
        self.mintable = false;
    }

    receive(msg: TransferOwnership){
        // Security check
        require(sender() == self.owner, "Not authorized to transfer ownership");
        // Update owner
        let oldOwner: Address = self.owner;
        self.owner = msg.newOwner;

        // Send acknowledgment
        send(SendParameters{
                to: msg.newOwner,
                value: 0,
                mode: SendRemainingValue,
                body: "Ownership transferred successfully".asComment()
            }
        );
    }
}

contract JettonWalletImp with JettonWallet, Deployable {
    balance: Int as coins = 0;
    owner: Address;
    jetton_master: Address;
    init(owner: Address, jetton_master: Address){
        self.owner = owner;
        self.jetton_master = jetton_master;
    }

    override inline fun calculate_jetton_wallet_init(owner_address: Address): StateInit {
        return initOf JettonWalletImp(owner_address, self.jetton_master);
    }

      // this message handler will just debug print the seqno so we can see when it's called
    receive("identify") {
        dump("Identified JettonWalletImp");
    }

    //Price = (Initial Price) * (1 + Purchase Amount / Liquidity Pool)^Curve Steepness
}