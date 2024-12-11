import "@stdlib/deploy";
import "@stdlib/ownable";
import "../messages";
import "../Jetton/JettonCore.tact";
// import "./Jetton/";

//Price = Initial Price * (1 + Purchase Amount / 0)^Curve Steepness
//Curve Steepness 1: /
//Curve Steepness 2: /^
//Curve Steepness 3: /^^

    // Struct to hold Jetton parameters
    struct JettonDeployParams {
        name: String;
        symbol: String;
        description: String;
        image: String;
        totalSupply: Int;
        adminAddress: Address;
    }

        // Message to deploy a new Jetton
    message DeployJetton {
        params: Cell; //JettonDeployParams;
       max_supply: Int;
        token_price: Int;
         initial_mint: Int;
          pool: Address;
    }

// Contract that deploys Jetton tokens
contract JettonFactory {
    owner: Address;
    
    init(owner: Address) {
        self.owner = owner;
    }
    

    

    
    // Deploy a new Jetton token 
    receive(msg: DeployJetton) {
        // Only owner can deploy tokens
        require(sender() == self.owner, "Only owner can deploy tokens");
        
     /*   // Create metadata cell
        let metadata: Cell = beginCell()
            .storeUint(1, 8) // on-chain marker
            .storeStringRefTail(msg.params.name)
            .storeStringRefTail(msg.params.symbol)
            .storeStringRefTail(msg.params.description)
            .storeStringRefTail(msg.params.image)
            .endCell(); */
            
        // Deploy Jetton contract
        let jettonInit: StateInit = initOf JettonCore(
            myAddress(),
          msg.params, // metadata,
            msg.max_supply,
            msg.token_price,
            msg.initial_mint,
            msg.pool,
        
        );
        
        let jettonAddress: Address = contractAddress(jettonInit);
        
        // Send deploy message
        send(SendParameters{
            to: jettonAddress,
            value: 0,
            mode: SendIgnoreErrors,
            bounce: true,
            code: jettonInit.code,
            data: jettonInit.data,
            body: beginCell()
                .storeUint(1, 32) // op for init
              
        .storeAddress(self.owner) // Store the owner address
        .storeStringRefTail(msg.params) // Store the token name
        .storeInt(msg.max_supply) // Store the maximum supply
        .storeInt(msg.token_price) // Store the token price
        .storeInt(msg.initial_mint) // Store the initial mint amount
        .storeAddress(msg.pool) // Store the pool address
                .endCell()
        });
    }
    
    // Getter to check owner
    get fun owner(): Address {
        return self.owner;
    }
}
