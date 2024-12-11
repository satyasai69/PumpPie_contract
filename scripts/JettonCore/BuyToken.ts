import { toNano, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { JettonCore } from '../../wrappers/jettonCore';

export async function run(provider: NetworkProvider) {
    const TOKEN_ADDRESS = 'EQBGl7Y--f-gX4PH3p8Jb_w8jAcnd3DHtJ-pCgsWC0PNHClw';
    const TON_AMOUNT = toNano(0.1); // Amount of TON to spend

    
   try {
        // Initialize JettonCore contract instance
        const jettonCore = provider.open(JettonCore.fromAddress(Address.parse(TOKEN_ADDRESS)));

    // Send the "BuyTokens" transaction
      await jettonCore.send(
            provider.sender(),
            {
                value: TON_AMOUNT, // The amount of TON being spent
            },
            {
                $$type: 'BuyTokens', // Explicitly specify the message type
                tokenAmount: TON_AMOUNT, // Include the amount being spent
            }
        );

        console.log(`BuyTokens transaction sent successfully with ${TON_AMOUNT.toString()} TON`);

        // Fetch total supply in coins from the contract
        const totalSupplyInCoins = await jettonCore.getGetTotalSupplyInCoins();

       // Log the total supply in coins
        console.log(`Total Supply: ${totalSupplyInCoins.toString()} coins`);



        
        // Get current price
        const price = await jettonCore.getGetCurrentPrice();
        console.log('Current Token Price:', price.toString());
         

        // Convert nano-TONs (BigInt) to TONs (Number) with decimal precision
        const priceInTon = Number(price) / 1_000_000_000;  // Convert to TONs (float)

      // Format to show 6 decimal places (adjust as needed)
      console.log('Price in TON:', priceInTon.toFixed(6));


        
        console.log('You can check the contract at:');
        console.log(`https://testnet.tonscan.org/address/${TOKEN_ADDRESS}`);
        
        return price;
    } catch (error) {
        console.error('Error getting current price:', error);
        throw error;
    }
}

