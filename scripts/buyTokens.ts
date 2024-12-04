import { toNano, Address, beginCell } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { Pool } from '../build/pool/tact_Pool';

export async function run(provider: NetworkProvider) {
    const POOL_ADDRESS = "EQB9gTUw1HgU7Q31Dx_iSgcHkRtNFCpn-WlaiJkHuwbPdaOx";
    const BUY_AMOUNT = "0.5"; // Amount of TON to spend on tokens
    const TOKEN_ADDRESS = "EQCWyU2afAy4t-JEX_JyIkade3e2sgoDmabmactSolt7efe7"; // Add the actual token address here

    // Initialize Pool contract instance
    const pool = provider.open(Pool.fromAddress(Address.parse(POOL_ADDRESS)));

    try {
        console.log('Buying tokens...');
        console.log('Pool Address:', POOL_ADDRESS);
        console.log('Amount to spend:', BUY_AMOUNT, 'TON');
        
        // Send buy transaction
        await pool.send(
            provider.sender(),
            {
                value: toNano(BUY_AMOUNT), // Amount of TON to spend
            },
            {
                $$type: 'BuyTokens',
              //  tokenAmount: toNano('0.5'), // Amount of tokens to buy
               // queryId: 0n
            }
        );

        console.log('Buy transaction sent');
        await provider.waitForDeploy(pool.address);

        // Get current price after buy
        const currentPrice = await pool.getGetCurrentPrice();
        console.log('Current token price:', currentPrice.toString(), 'nanoTON');

        console.log(`Successfully bought tokens with ${BUY_AMOUNT} TON`);
        console.log('You can check your transaction at:');
        console.log(`https://testnet.tonscan.org/address/${POOL_ADDRESS}`);

    } catch (error) {
        console.error('Error occurred while buying tokens:', error);
        console.log('Please check:');
        console.log('1. You have enough TON in your wallet');
        console.log('2. The pool address is correct');
        console.log('3. The pool contract is properly deployed');
    }
}
