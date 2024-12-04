import "@stdlib/deploy";
import "@stdlib/ownable";

// Constants
const DECIMALS: Int = 1000000000; // 10^9 for TON
const MAX_SUPPLY: Int = 1000000 * DECIMALS;
const INIT_SUPPLY: Int = (20 * MAX_SUPPLY) / 100;
const INITIAL_PRICE: Int = 30000000000000;  // Initial price in nanoTON
const K: Int = 8000000000000000;  // Growth rate

message CreateMemeToken {
    name: String;
    symbol: String;
    description: String;
    tokenImageUrl: String;
    decimals: Int;
    maxSupply: Int;
    initSupply: Int;
    initialPrice: Int;
    k: Int;
}

message BuyTokens {
    amount: Int;
}

// Struct for MemeToken info
struct MemeToken {
    name: String;
    symbol: String;
    description: String;
    tokenImageUrl: String;
    fundingRaised: Int;
    tokenAddress: Address;
    creatorAddress: Address;
    decimals: Int;
    maxSupply: Int;
    currentSupply: Int;
    currentPrice: Int;
    k: Int;
}

contract PumpToken with Deployable, Ownable {
    owner: Address;
    memeTokenAddresses: map<Int, Address>;
    addressToMemeToken: map<Address, MemeToken>;
    totalTokens: Int = 0;
    
    init() {
        self.owner = sender();
    }

    // Helper function to calculate exponential (e^x)
    fun exp(x: Int): Int {
        let sum: Int = DECIMALS;
        let term: Int = DECIMALS;
        let xPower: Int = x;
        let iter: Int = 1;
        
        repeat(20) {
            term = (term * xPower) / (iter * DECIMALS);
            sum = sum + term;
            iter = iter + 1;
            
            if (term < 1) {
                return sum;
            }
        }
        
        return sum;
    }

    // Calculate cost based on bonding curve
    fun calculateCost(currentSupply: Int, tokensToBuy: Int): Int {
        let exponent1: Int = (K * (currentSupply + tokensToBuy)) / DECIMALS;
        let exponent2: Int = (K * currentSupply) / DECIMALS;
        
        let exp1: Int = self.exp(exponent1);
        let exp2: Int = self.exp(exponent2);
        
        return (INITIAL_PRICE * DECIMALS * (exp1 - exp2)) / K;
    }

    // Create new meme token
    receive(msg: CreateMemeToken) {
        require(context().value >= ton("0.1"), "Insufficient fee for token creation");
        
        // Create new token entry
        let newToken: MemeToken = MemeToken{
            name: msg.name,
            symbol: msg.symbol,
            description: msg.description,
            tokenImageUrl: msg.tokenImageUrl,
            fundingRaised: 0,
            tokenAddress: myAddress(),
            creatorAddress: sender(),
            decimals: msg.decimals,
            maxSupply: msg.maxSupply,
            currentSupply: msg.initSupply,
            currentPrice: msg.initialPrice,
            k: msg.k
        };
        
        self.memeTokenAddresses.set(self.totalTokens, sender());
        self.addressToMemeToken.set(sender(), newToken);
        self.totalTokens = self.totalTokens + 1;
    }

    // Buy meme tokens
    receive(msg: BuyTokens) {
        let amount: Int = context().value;
        require(amount > 0, "Must send positive TON value");
        
        // Implementation for token purchase logic
        // This would calculate tokens based on bonding curve and transfer
    }

    // Get all meme tokens
    get fun getAllMemeTokens(): map<Address, MemeToken> {
        return self.addressToMemeToken;
    }

    // Getter for total number of tokens
    get fun getTotalTokens(): Int {
        return self.totalTokens;
    }
}
