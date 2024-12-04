import "@stdlib/deploy";
import "@stdlib/ownable";
import "../Jetton/traits/JettonMaster";
import "../Jetton/Jetton";

message BuyTokens {
    tokenAmount: Int;
}

message SellTokens {
    amount: Int;  // Amount of tokens to sell
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
    const K: Int = 8000000000000000;  // Growth rate
    const INITIAL_PRICE: Int = 30000000000000;  // Initial price in nanoTON

    owner: Address;
    tokenAddress: Address;
    tokenData: JettonData;

    init(token: Address) {
        self.owner = sender();
        self.tokenAddress = token;
        self.tokenData = JettonData{
            total_supply: 0,
            mintable: false,
            admin_address: self.owner,
            jetton_content: emptyCell(),
            jetton_wallet_code: emptyCell()
        };
    }

    receive(msg: BuyTokens) {
        let amount: Int = context().value;
        require(amount > ton("0.2"), "Must send at least 0.2 TON for gas");
        
        // Get current supply and calculate cost
        let currentSupply: Int = self.getTokenSupply();
        let availableTon: Int = amount - ton("0.15"); // Reserve 0.15 TON for gas
        let cost: Int = self.calculateCost(currentSupply, self.DECIMALS); // Cost for 1 token unit
        
        // Calculate tokens to mint based on available TON
        let tokensToMint: Int = (availableTon * self.DECIMALS) / cost;
        require(tokensToMint > 0, "Amount too small to mint tokens");
        
        // Get token data and verify mintable
        let data: JettonData = self.getTokenData();
        require(data.mintable, "Token is not mintable");
        
        // Mint tokens to sender
        send(SendParameters{
            to: self.tokenAddress,
            value: ton("0.1"),  // Send 0.1 TON for minting operation
            mode: 1,  // SendIgnoreErrors
            body: JettonMint{
                origin: myAddress(),  // Pool contract is the origin
                receiver: sender(),   // Token buyer is the receiver
                amount: tokensToMint,
                custom_payload: null,
                forward_ton_amount: ton("0.05"),  // Forward some TON for wallet init
                forward_payload: emptySlice()
            }.toCell()
        });
    }

    receive(msg: SellTokens) {
        // Calculate TON to return based on current supply
        let currentSupply: Int = self.getTokenSupply();
        let newSupply: Int = currentSupply - msg.amount;
        let returnAmount: Int = self.calculateCost(newSupply, msg.amount);
        
        // Reserve some TON for gas
        require(returnAmount > ton("0.1"), "Sell amount too small");
        
        // Burn the tokens first
        send(SendParameters{
            to: self.tokenAddress,
            value: ton("0.1"),  // Send 0.1 TON for burn operation
            mode: 1,  // SendIgnoreErrors
            body: JettonBurn{
                query_id: 0,
                amount: msg.amount,
                custom_payload: null,
                response_destination: myAddress()  // Pool will receive burn notification
            }.toCell()
        });
    }

    receive(msg: JettonBurnNotification) {
        // Verify notification is from token contract
        require(sender() == self.tokenAddress, "Invalid burn notification");
        
        // Calculate TON to return
        let currentSupply: Int = self.getTokenSupply();
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

    fun calculateCost(currentSupply: Int, tokensToBuy: Int): Int {
        let exponent1: Int = (self.K * (currentSupply + tokensToBuy)) / self.DECIMALS;
        let exponent2: Int = (self.K * currentSupply) / self.DECIMALS;
        
        let exp1: Int = self.exp(exponent1);
        let exp2: Int = self.exp(exponent2);
        
        return (self.INITIAL_PRICE * self.DECIMALS * (exp1 - exp2)) / self.K;
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
        let currentSupply: Int = self.getTokenSupply();
        // Calculate price for 1 token unit (DECIMALS)
        return self.calculateCost(currentSupply, self.DECIMALS);
    }

    get fun getTokenSupply(): Int {
        let data: JettonData = self.getTokenData();
       //let data: JettonData = self.fetch_jetton_data();
        return data.total_supply;
    }
}