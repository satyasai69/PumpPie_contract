import "@stdlib/deploy";
import "@stdlib/ownable";
import "../Jetton/traits/JettonMaster";
import "../Jetton/Jetton";

message BuyTokens {
   // tokenAmount: Int;
}

message SellTokens {
    tokenAmount: Int;  // Amount of tokens to sell
    from: Address;  // Address of token holder
}

/*message JettonBurnNotification {
    amount: Int;
    sender: Address;
} */

message GetJettonData {
    query_id: Int as uint64;
}

message GetJettonDataResponse {
    query_id: Int as uint64;
    data: JettonData;
}

/* struct JettonData {
    total_supply: Int;
    mintable: Bool;
    admin_address: Address;
    jetton_content: Cell;
    jetton_wallet_code: Cell;
} */

contract Pool with Deployable, Ownable {
    const DECIMALS: Int = 1000000000; // 10^9 for TON
    const K: Int = 100000; // Growth rate multiplier
    const INITIAL_PRICE: Int = 30000000000000;  // Initial price in nanoTON

    owner: Address;
    tokenAddress: Address;
    tokenData: JettonData;
    lastPrice: Int;  // Track last price for verification

    init(token: Address) {
        self.owner = sender();
        self.tokenAddress = token;
        self.lastPrice = self.INITIAL_PRICE;
        self.tokenData = JettonData{
            total_supply: 1000000000000000000,
            mintable: true,
            admin_address: self.owner,
            jetton_content: emptyCell(),
            jetton_wallet_code: emptyCell()
        };
    }

    receive(msg: BuyTokens) {
        let amount: Int = context().value;
        require(amount > ton("0.2"), "Must send at least 0.2 TON for gas");
        require(self.tokenData.mintable, "Token not mintable");
          
        // Calculate available TON for token purchase
        let availableTon: Int = amount - ton("0.15"); // Reserve 0.15 TON for gas
        
        // Get current price per token unit
        let currentSupply: Int = self.tokenData.total_supply;
        let pricePerToken: Int = self.calculateCost(currentSupply, 1000000000);
        require(pricePerToken > 0, "Invalid token price");
        
        // Calculate tokens to mint with overflow protection
        let tokensToMint: Int = (availableTon * 1000000000) / pricePerToken;
        require(tokensToMint > 0, "Amount too small to mint tokens");
        require(tokensToMint <= 1000000000000, "Too many tokens per transaction");
        
        // Update total supply
        self.tokenData.total_supply = self.tokenData.total_supply + tokensToMint;
        
        // Log values for debugging
        dump("Buy Operation:");
        dump("Current Supply: ");
        dump(currentSupply);
        dump("Price Per Token: ");
        dump(pricePerToken);
        dump("Tokens to Mint: ");
        dump(tokensToMint);
        dump("New Supply: ");
        dump(self.tokenData.total_supply);
        
        // Mint tokens to sender
        send(SendParameters{
            to: self.tokenAddress,
            value: ton("0.1"),
            mode: 1,
            body: JettonMint{
                origin: myAddress(),
                receiver: sender(),
                amount: tokensToMint,
                custom_payload: null,
                forward_ton_amount: ton("0.05"),
                forward_payload: emptySlice()
            }.toCell()
        });
    }

    receive(msg: SellTokens) {
        // Calculate TON to return based on current supply
        let currentSupply: Int = self.tokenData.total_supply;
        let newSupply: Int = currentSupply - msg.tokenAmount;
        require(newSupply >= 0, "Not enough tokens in supply");
        
        // Calculate sell price (slightly lower than buy price)
        let currentPrice: Int = self.calculateCost(currentSupply, msg.tokenAmount);
        let sellPrice: Int = (currentPrice * 95) / 100; // 5% lower than buy price
        let returnAmount: Int = (msg.tokenAmount * sellPrice) / self.DECIMALS;
        
        // Reserve some TON for gas
        require(returnAmount > ton("0.1"), "Sell amount too small");
        require(returnAmount < ton("100"), "Sell amount too large"); // Add upper limit
        
        // Update total supply
        self.tokenData.total_supply = newSupply;
        
        // Log values for debugging
        dump("Sell Operation:");
        dump("Current Supply: ");
        dump(currentSupply);
        dump("Tokens to Burn: ");
        dump(msg.tokenAmount);
        dump("Sell Price: ");
        dump(sellPrice);
        dump("Return Amount: ");
        dump(returnAmount);
        dump("New Supply: ");
        dump(newSupply);
        
        // Burn the tokens first
        send(SendParameters{
            to: self.tokenAddress,
            value: ton("0.1"),
            mode: 1,
            body: JettonBurn{
                query_id: 0,
                amount: msg.tokenAmount,
                custom_payload: null,
                response_destination: myAddress()
            }.toCell()
        });
        
        // Send TON back to user
        send(SendParameters{
            to: msg.from,
            value: returnAmount - ton("0.1"),
            mode: 1,
            body: "Tokens sold successfully".asComment()
        });
    }

    receive(msg: JettonBurnNotification) {
        // Verify notification is from token contract
        require(sender() == self.tokenAddress, "Invalid burn notification");
        
        // Calculate TON to return
        let currentSupply: Int = self.tokenData.total_supply;
        let returnAmount: Int = self.calculateCost(currentSupply, msg.amount);
        
        // Send TON back to user
        send(SendParameters{
            to: msg.sender,  // Original sender who burned tokens
            value: returnAmount - ton("0.1"),  // Reserve 0.1 TON for gas
            mode: 1,  // SendIgnoreErrors
            body: "Tokens sold successfully".asComment()
        });
    }

    receive(msg: GetJettonDataResponse) {
        // Handle the response from Jetton contract
        require(sender() == self.tokenAddress, "Invalid response sender");
        self.tokenData = msg.data;
    }

    fun exp(x: Int): Int {
        let sum: Int = self.DECIMALS;
        let term: Int = self.DECIMALS;
        let xPower: Int = x;
        let iter: Int = 1;
        
        repeat(20) {
            term = (term * xPower) / (iter * self.DECIMALS);
            sum = sum + term;
            iter = iter + 1;
            
            if (term < 1) {
                return sum;
            }
        }
        
        return sum;
    }

    fun calculateCost(currentSupply: Int, tokenAmount: Int): Int {
        // Convert supply to whole tokens
        let supplyInTokens: Int = currentSupply / self.DECIMALS;
        
        // Normalize supply to prevent overflow
        // Use smaller numbers for calculation
        let basePrice: Int = self.INITIAL_PRICE / 1000000000; // Convert to TON units
        let normalizedSupply: Int = supplyInTokens / 1000000; // Scale down supply
        
        // Calculate price with controlled growth
        let priceIncrease: Int = (normalizedSupply * normalizedSupply) / 10000;
        let finalPrice: Int = basePrice + (basePrice * priceIncrease) / 100;
        
        // Convert back to nanoTON
        return finalPrice * 1000000000;
    }

    get fun getTokenData(): JettonData {    
        send(SendParameters{
            to: self.tokenAddress,
            value: ton("0.1"),
            mode: SendRemainingValue,
            body: GetJettonData{
                query_id: now()
            }.toCell()
        });

        // Return cached data
        return self.tokenData;
    }   

    get fun getCurrentPrice(): Int {
        let currentSupply: Int = self.tokenData.total_supply;
        return self.calculateCost(currentSupply, self.DECIMALS);
    }

    get fun getTokenSupply(): Int {
        return self.tokenData.total_supply;
    }
}