import { toNano, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { PoolCore } from '../../wrappers/PoolCore';

export async function run(provider: NetworkProvider) {
    // Configuration
    const PoolCore_ADDRESS = "EQBaScBaDYJZ6PClixpIGNpl_ABp9MNVYiJzB_9N--N5li7v";
    const JETTON_ADDRESS = "EQAnOgaiBDkmfc9wfSRUsUtjDOLzVw3zHuHEPRwO0dFNUJA0"; // Replace with your Jetton address

    try {
        console.log('Starting pool deployment...');
        console.log('PoolCore Address:', PoolCore_ADDRESS);
        console.log('Jetton Address:', JETTON_ADDRESS);

        // Get Factory contract instance
        const PoolCoreAdd = provider.open(PoolCore.fromAddress(Address.parse(PoolCore_ADDRESS)));

        // Deploy Pool for the Jetton
        console.log('\nSending deployment transaction...');
     await PoolCoreAdd.send(
            provider.sender(),
            {
                value: toNano('0.01'), // 1 TON for deployment + 0.1 TON for fees
            },
            {
                $$type: 'AddJetton',
                jettonAddress: Address.parse(JETTON_ADDRESS)
            }
        ); 
        
        console.log('Deployment transaction sent');
        await provider.waitForDeploy(PoolCoreAdd.address); 

        // Check if pool exists and get pool information
        const hasPool = await PoolCoreAdd.getHasPool(Address.parse(JETTON_ADDRESS));
        console.log('Pool exists for Jetton:', hasPool);

        if (hasPool) {
            const liquidity = await PoolCoreAdd.getGetJettonLiquidity(Address.parse(JETTON_ADDRESS));
            console.log('Pool Liquidity:', liquidity.toString());
        }

        // Get and log the pool address
   //     const poolAddress = await PoolCoreAdd.getGetJettonToPool(Address.parse(JETTON_ADDRESS));
     //   console.log('Pool Address for Jetton:', poolAddress.toString());

        
    } catch (error) {
        console.error('Error deploying pool:', error);
       
    }
}
