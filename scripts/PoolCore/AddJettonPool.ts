import { toNano, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { Factory } from '../../build/Factory/tact_Factory';
import { PoolCore } from '../../wrappers/PoolCore';

export async function run(provider: NetworkProvider) {
    // Configuration
    const PoolCore_ADDRESS = "EQCml35ZSm5pCSEFO3aWRlGi0NspQh2jbKed8_w0rbwD9R0O";
    const JETTON_ADDRESS = "EQBGl7Y--f-gX4PH3p8Jb_w8jAcnd3DHtJ-pCgsWC0PNHClw"; // Replace with your Jetton address

    try {
        console.log('Starting pool deployment...');
        console.log('PoolCore Address:', PoolCore_ADDRESS);
        console.log('Jetton Address:', JETTON_ADDRESS);

        // Get Factory contract instance
        const PoolCoreAdd = provider.open(PoolCore.fromAddress(Address.parse(PoolCore_ADDRESS)));

        // Deploy Pool for the Jetton
        console.log('\nSending deployment transaction...');
      /*  await PoolCoreAdd.send(
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
        await provider.waitForDeploy(PoolCoreAdd.address); */


        
       const liq = await PoolCoreAdd.getGetJettonLiquidity(PoolCoreAdd.address);
       console.log('Jetton Liquidity:', liq.toString());
      

       
    } catch (error) {
        console.error('Error deploying pool:', error);
       
    }
}
