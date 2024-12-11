import { toNano, Address, beginCell } from '@ton/core';
import { Jetton } from '../../wrappers/Jetton';
import { Factory } from '../../wrappers/Factory';
import { NetworkProvider } from '@ton/blueprint';
import { buildOnchainMetadata } from '../../utils/jetton-helpers';

export async function run(provider: NetworkProvider) {
    // Deploy Jetton first
    const jettonContent = {
        name: "Test Token 3",
        symbol: "TST3",
        description: "Test Token for Pool",
        image: "https://example.com/image.png"
    };

    let content = buildOnchainMetadata(jettonContent);

    let Max_Supply: bigint = 100000000000000000000n; 
    let initial_Price: bigint = 10000n;
    let iinitial_mint_Amount: bigint = 10000000000000n;

    const PoolCore_ADDRESS = "EQCml35ZSm5pCSEFO3aWRlGi0NspQh2jbKed8_w0rbwD9R0O";
    
    const jetton = provider.open(await Jetton.fromInit(
        provider.sender().address!, // admin
        content,
        Max_Supply,
        initial_Price,
        iinitial_mint_Amount,
        PoolCore_ADDRESS
    ));

    // Deploy Jetton contract
    await jetton.send(
        provider.sender(),
        {
            value: toNano('0.5'),
        },
        {
            $$type: 'Deploy',
            queryId: 0n,
        }
    );

    await provider.waitForDeploy(jetton.address);
    console.log('Jetton deployed at:', jetton.address);

    // Get Factory contract instance
    const factory = provider.open(Factory.fromAddress(Address.parse("EQB3GYfP2EBtEHWW_sLYsHSHaYUT7AsH8r_drETw0jyBZv1T")));

    // Deploy Pool for the Jetton
    await factory.send(
        provider.sender(),
        {
            value: toNano('1.5'), // 1.3 TON minimum (1 TON fee + 0.2 TON deployment + gas)
        },
        {
            $$type: 'DeployPool',
            tokenAddress: jetton.address,
        }
    );

    console.log('Pool deployment transaction sent');
    
    // Wait for deployment to complete
    await provider.waitForDeploy(factory.address);
    
    // Wait a bit to make sure state is updated
    await new Promise(resolve => setTimeout(resolve, 5000));

    // Get total pools and pool address
    const totalPools = await factory.getGetTotalPools();
    const poolAddress = await factory.getGetPool(jetton.address);
    
    // Log all addresses
    console.log('Deployment completed:');
    console.log('- Total pools:', totalPools);
    console.log('- Jetton:', jetton.address.toString());
    console.log('- Factory:', factory.address.toString());
    console.log('- Pool:', poolAddress ? poolAddress.toString() : 'Not found');
}
