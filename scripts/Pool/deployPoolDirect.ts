import { toNano, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { Pool } from '../../build/pool/tact_Pool';

export async function run(provider: NetworkProvider) {
    // Configuration
    const JETTON_ADDRESS = "EQCWyU2afAy4t-JEX_JyIkade3e2sgoDmabmactSolt7efe7"; // Replace with your Jetton address

    try {
        console.log('Starting direct pool deployment...');
        console.log('Jetton Address:', JETTON_ADDRESS);

        // Create Pool contract instance
        const pool = provider.open(await Pool.fromInit(
            Address.parse(JETTON_ADDRESS)  // token address
        ));

        // Deploy Pool contract
        console.log('\nSending deployment transaction...');
        await pool.send(
            provider.sender(),
            {
                value: toNano('1'), // TON for deployment
            },
            {
                $$type: 'Deploy',
                queryId: 0n
            }
        );

        console.log('Deployment transaction sent');
        console.log('Pool address:', pool.address.toString());

        // Wait for deployment
        await provider.waitForDeploy(pool.address);
        console.log('Pool contract deployed successfully');
        
    } catch (error) {
        console.error('Error deploying Pool contract:', error);
        process.exit(1);
    }
}
