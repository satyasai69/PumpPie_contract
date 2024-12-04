import "@stdlib/deploy";
import "@stdlib/ownable";
import "../Jetton/Jetton";

message Deploy {
    queryId: Int as uint64;
}

contract Core with Deployable, Ownable {
    owner: Address;
    totalChildContracts: Int;

    init() {
        self.owner = sender();
        self.totalChildContracts = 0;
    }

    

    fun deployChildContract(jettonContent: Cell) {
        // Create Jetton contract initialization
        let init: StateInit = initOf Jetton(myAddress(), jettonContent);
        let childAddress: Address = contractAddress(init);

        send(SendParameters{
            to: childAddress,
            value: ton("0.1"),
            mode: 1, // SendIgnoreErrors = 1
            code: init.code,
            data: init.data,
            body: Deploy{queryId: 0}.toCell()
        });

        self.totalChildContracts += 1;
    }
}