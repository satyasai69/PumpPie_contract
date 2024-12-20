import { toNano, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { JettonCore } from '../../wrappers/jettonCore';
import { PoolCore } from '../../wrappers/PoolCore';

export async function run(provider: NetworkProvider) {
    const PoolCore_ADDRESS = "EQATkHBGHMeE_ilq3SX7e4Jz6GwspaDRh97AX0khWFUHRIVb";
    const TOKEN_ADDRESS = 'EQAI18UHqCdMRiRerg1FbVeBFPr_S9U5POCjGgM3Oq9gZ1W3';
    const TOKEN_AMOUNT = toNano(0.5); // Amount of TON to spend

    
   try {
        // Initialize JettonCore contract instance
        const PoolCores = provider.open(PoolCore.fromAddress(Address.parse(PoolCore_ADDRESS)));
        const TOKEN = provider.open(JettonCore.fromAddress(Address.parse(TOKEN_ADDRESS)));


    // Send the "BuyTokens" transaction
     await PoolCores.send(
            provider.sender(),
            {
                value: toNano(0.3), // The amount of TON being spent
             //   bounce: false,
            },
            {
                $$type: 'PoolSell', // Explicitly specify the message type
                jettonAddress: Address.parse(TOKEN_ADDRESS),
                to: Address.parse("EQAXPxxHYsTmCWowXn66wPQpO_jqyiZ7ckumefvQ2YF4snFV"),
                amount: TOKEN_AMOUNT, // Include the amount being spent
            }
        );  

     /*  await PoolCores.send(
            provider.sender(),
            {
                value: toNano(0.01), // The amount of TON being spent
            },
            "withdrawAllTon" // Use the simple withdraw all function
        ); */

        console.log(`BuyTokens transaction sent successfully with ${TOKEN_AMOUNT.toString()} Jettons`);

        // Fetch total supply in coins from the contract
        const totalSupplyInCoins = await TOKEN.getGetTotalSupplyInCoins();

       // Log the total supply in coins
        console.log(`Total Supply: ${totalSupplyInCoins.toString()} coins`);



        
        // Get current price
        const price = await TOKEN.getGetCurrentPrice();
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
