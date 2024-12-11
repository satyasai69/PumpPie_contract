import { toNano, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { Pool } from '../../build/pool/tact_Pool';

export async function run(provider: NetworkProvider) {
    const POOL_ADDRESS = "EQB9gTUw1HgU7Q31Dx_iSgcHkRtNFCpn-WlaiJkHuwbPdaOx";
    const AMOUNT_TO_SELL = "100"; // Amount of tokens to sell

    try {
        console.log('Starting token sell operation...');
        console.log('Pool Address:', POOL_ADDRESS);
        console.log('Amount to sell:', AMOUNT_TO_SELL, 'tokens');

        // Open pool contract
        const pool = provider.open(Pool.fromAddress(Address.parse(POOL_ADDRESS)));

        // Send sell transaction
        console.log('\nSending sell transaction...');
        await pool.send(
            provider.sender(),
            {
                value: toNano('0.5'), // Increased gas value
            },
            {
                $$type: 'SellTokens',
                tokenAmount: toNano(AMOUNT_TO_SELL), // Amount of tokens to sell
                from: provider.sender().address!
            }
        );

        console.log('Sell transaction sent');
        await provider.waitForDeploy(pool.address);

        // Get current price after sell
        const currentPrice = await pool.getGetCurrentPrice();
        console.log('Current token price:', currentPrice.toString(), 'nanoTON');

        console.log(`Successfully sold ${AMOUNT_TO_SELL} tokens to pool`);

    } catch (error) {
        console.error('Error occurred while selling tokens:', error);
        process.exit(1);
    }
}
