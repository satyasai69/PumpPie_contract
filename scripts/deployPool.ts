import { toNano, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { Factory } from '../build/Factory/tact_Factory';

export async function run(provider: NetworkProvider) {
    // Configuration
    const FACTORY_ADDRESS = "EQB3GYfP2EBtEHWW_sLYsHSHaYUT7AsH8r_drETw0jyBZv1T";
    const JETTON_ADDRESS = "EQCBEyy64T2bk0J13d0vhU4ZDygWaCtMrEYSUszEvxfl5KEJ"; // Replace with your Jetton address

    try {
        console.log('Starting pool deployment...');
        console.log('Factory Address:', FACTORY_ADDRESS);
        console.log('Jetton Address:', JETTON_ADDRESS);

        // Get Factory contract instance
        const factory = provider.open(Factory.fromAddress(Address.parse(FACTORY_ADDRESS)));

        // Deploy Pool for the Jetton
        console.log('\nSending deployment transaction...');
        await factory.send(
            provider.sender(),
            {
                value: toNano('1.1'), // 1 TON for deployment + 0.1 TON for fees
            },
            {
                $$type: 'DeployPool',
                tokenAddress: Address.parse(JETTON_ADDRESS)
            }
        );

        console.log('Deployment transaction sent');
        await provider.waitForDeploy(factory.address);

        // Get pool address
        const poolAddress = await factory.getGetPool(Address.parse(JETTON_ADDRESS));
        
        console.log('\nDeployment Summary:');
        console.log('- Factory Address:', FACTORY_ADDRESS);
        console.log('- Jetton Address:', JETTON_ADDRESS);
        console.log('- Pool Address:', poolAddress ? poolAddress.toString() : 'Not created yet');

        // Get total pools
        const totalPools = await factory.getGetTotalPools();
        console.log('- Total Pools:', totalPools.toString());

        if (poolAddress) {
            console.log('\nPool successfully deployed!');
            console.log('View on TON Explorer:');
            console.log(`https://testnet.tonscan.org/address/${poolAddress.toString()}`);
        } else {
            console.log('\nWarning: Pool address not found after deployment');
            console.log('Please wait a few seconds and check the explorer manually');
        }

    } catch (error) {
        console.error('Error deploying pool:', error);
        console.log('\nPlease check:');
        console.log('1. You have enough TON in your wallet (at least 1.1 TON)');
        console.log('2. The Factory address is correct');
        console.log('3. The Jetton address is correct');
        console.log('4. A pool does not already exist for this Jetton');
    }
}
