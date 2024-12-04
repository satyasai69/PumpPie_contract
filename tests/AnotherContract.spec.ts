import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { toNano } from '@ton/core';
import { AnotherContract } from '../wrappers/AnotherContract';
import '@ton/test-utils';

describe('AnotherContract', () => {
    let blockchain: Blockchain;
    let deployer: SandboxContract<TreasuryContract>;
    let anotherContract: SandboxContract<AnotherContract>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();

        anotherContract = blockchain.openContract(await AnotherContract.fromInit());

        deployer = await blockchain.treasury('deployer');

        const deployResult = await anotherContract.send(
            deployer.getSender(),
            {
                value: toNano('0.05'),
            },
            {
                $$type: 'Deploy',
                queryId: 0n,
            }
        );

        expect(deployResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: anotherContract.address,
            deploy: true,
            success: true,
        });
    });

    it('should deploy', async () => {
        // the check is done inside beforeEach
        // blockchain and anotherContract are ready to use
    });
});
