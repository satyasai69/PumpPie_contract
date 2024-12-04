import { toNano, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { Pool } from '../build/pool/tact_Pool';

export async function run(provider: NetworkProvider) {
    // Initialize Pool contract instance
    const poolAddress = Address.parse("EQC51OUneAffg7uH4QkrOuYMy4z6WfEsSzGb1Opn1tL1qam5");
    const pool = provider.open(Pool.fromAddress(poolAddress));

    try {
        // First, let's buy some tokens
        console.log('Buying tokens...');
        await pool.send(
            provider.sender(),
            {
                value: toNano('1'), // Sending 1 TON (adjust amount as needed)
            },
            {
                $$type: 'BuyTokens',
                tokenAmount: toNano('1') // Amount of tokens to buy
            }
        );

        console.log('Buy transaction sent');
        await provider.waitForDeploy(pool.address);

        // Wait a bit before selling
        await new Promise(resolve => setTimeout(resolve, 5000));

        // Now let's sell some tokens
        console.log('\nSelling tokens...');
        await pool.send(
            provider.sender(),
            {
                value: toNano('0.2'), // Gas for the operation
            },
            {
                $$type: 'SellTokens',
                amount: toNano('0.5'), // Amount of tokens to sell
                from: provider.sender().address!
            }
        );

        console.log('Sell transaction sent');
        await provider.waitForDeploy(pool.address);
        
        console.log('All transactions completed');
    } catch (error) {
        console.error('Error occurred:', error);
    }
}
