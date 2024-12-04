import "@stdlib/deploy";
import "@stdlib/ownable";
import "../messages";
import "./Jetton/";

// Contract that deploys Jetton tokens
contract JettonFactory {
    owner: Address;
    
    init(owner: Address) {
        self.owner = owner;
    }
    
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
        params: JettonDeployParams;
    }
    
    // Deploy a new Jetton token
    receive(msg: DeployJetton) {
        // Only owner can deploy tokens
        require(sender() == self.owner, "Only owner can deploy tokens");
        
        // Create metadata cell
        let metadata: Cell = beginCell()
            .storeUint(1, 8) // on-chain marker
            .storeStringRefTail(msg.params.name)
            .storeStringRefTail(msg.params.symbol)
            .storeStringRefTail(msg.params.description)
            .storeStringRefTail(msg.params.image)
            .endCell();
            
        // Deploy Jetton contract
        let jettonInit: StateInit = initOf Jetton(
            msg.params.adminAddress,
            metadata,
            myAddress()
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
                .storeCoins(msg.params.totalSupply)
                .endCell()
        });
    }
    
    // Getter to check owner
    get fun owner(): Address {
        return self.owner;
    }
}
