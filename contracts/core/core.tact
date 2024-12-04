import "@stdlib/deploy";
import "@stdlib/ownable";
import "../Jetton/Jetton";
import "../messages";

message DeployJetton {
   // queryId: Int as uint64;
    jettonContent: Cell;
    initialSupply: Int as coins;
}

message BuyTokens {
   tokenAddress: Address;
    tokenAmount: Int;
}
message SellTokens {
     tokenAddress: Address;
    tokenAmount: Int;
}

message RegisterToken {
    tokenAddress: Address;
}

message VerifyJetton {
    queryId: Int as uint64;
    tokenAddress: Address;
}

message JettonVerified {
    queryId: Int as uint64;
    isJetton: Bool;
}

contract Core with Deployable, Ownable {
    owner: Address;
    totalChildContracts: Int;
    tokenAddresses: map<Int, Address>;  // Map to store token addresses
    verifiedJettons: map<Address, Bool>; // Map to track verified Jetton contracts

    init() {
        self.owner = sender();
        self.totalChildContracts = 0;
    }

    receive(msg: DeployJetton) {
        // Ensure only owner can deploy
        require(sender() == self.owner, "Only owner can deploy");

        // Create Jetton contract initialization
        let init: StateInit = initOf Jetton(myAddress(), msg.jettonContent, msg.initialSupply);
        let childAddress: Address = contractAddress(init);

        send(SendParameters{
            to: childAddress,
            value: ton("0.1"),
            mode: 1, // SendIgnoreErrors = 1
            code: init.code,
            data: init.data,
            body: DeployJetton{
              //  queryId: msg.queryId,
                jettonContent: msg.jettonContent,
                initialSupply: msg.initialSupply
            }.toCell()
        });

        // Store the token address
        self.tokenAddresses.set(self.totalChildContracts, childAddress);
        self.totalChildContracts = self.totalChildContracts + 1;
    }

    receive(msg: BuyTokens) {
        // Ensure only owner can buy tokens
        require(sender() == self.owner, "Only owner can buy tokens");

        // Check if token is verified
        let isVerified: Bool = self.verifiedJettons.get(msg.tokenAddress) ?: false;
        require(isVerified, "Token is not verified");

        let tokenAddress: Address = msg.tokenAddress;
        let tokenAmount: Int = msg.tokenAmount;

        // Only proceed if token is verified
        send(SendParameters{
            to: tokenAddress,
            value: tokenAmount,
            mode: 1, // SendIgnoreErrors = 1
            body: BuyTokens{
                tokenAddress: tokenAddress,
                tokenAmount: tokenAmount
            }.toCell()
        });
    }

    receive(msg: RegisterToken) {
        // Ensure only owner can register tokens
        require(sender() == self.owner, "Only owner can register tokens");

        // Check if the token is already registered
        let isRegistered: Bool = false;
        let i: Int = 0;
        repeat (self.totalChildContracts) {
            if (self.tokenAddresses.get(i) == msg.tokenAddress) {
                isRegistered = true;
            }
            i = i + 1;
        }

        require(!isRegistered, "Token is already registered");

        // Store the token address
        self.tokenAddresses.set(self.totalChildContracts, msg.tokenAddress);
        self.totalChildContracts = self.totalChildContracts + 1;

        // Send verification request to the token contract
        send(SendParameters{
            to: msg.tokenAddress,
            value: ton("0.1"),
            mode: 1, // SendIgnoreErrors = 1
            body: VerifyJetton{
                queryId: now(),
                tokenAddress: msg.tokenAddress
            }.toCell()
        });
    }

    receive(msg: JettonVerified) {
        // Store the verification result
        self.verifiedJettons.set(msg.tokenAddress, msg.isJetton);
    }

    //=================== GETTERS =====================//

    // Getter to retrieve token address by index
    get fun getTokenAddress(index: Int): Address? {
        return self.tokenAddresses.get(index);
    }

    // Getter to get total number of tokens
    get fun getTotalTokens(): Int {
        return self.totalChildContracts;
    }

    // Getter to check if an address is a verified Jetton
    get fun isVerifiedJetton(address: Address): Bool {
        return self.verifiedJettons.get(address) ?: false;
    }
}