import "@stdlib/deploy";
import "./traits/JettonMaster.tact";
import "./traits/JettonWallet.tact";


message TransferOwnership {
  //  queryId: Int as uint64;  // Added standard queryId
    newOwner: Address;
}

contract Jetton with JettonMaster, Deployable {
    total_supply: Int as coins;
    owner: Address;
    jetton_content: Cell;
    mintable: Bool;



    init(owner: Address, content: Cell){ // initial_supply: Int
       // require(initial_supply > 0, "Initial supply must be greater than 0");
        self.total_supply = 0;
        self.owner = owner;
        self.mintable = true;
        self.jetton_content = content;
    }

    override inline fun calculate_jetton_wallet_init(owner_address: Address): StateInit {
        return initOf JettonWalletImp(owner_address, myAddress());
    }

    receive("Mint:Close"){
        let ctx: Context = context();
        require(ctx.sender == self.owner, "JettonMaster: Sender is not a Jetton owner");
        self.mintable = false;
    }

   receive(msg: TransferOwnership) {
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
    });
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
}