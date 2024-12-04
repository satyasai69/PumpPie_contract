
 import { Address, toNano, beginCell } from '@ton/core';
import { Jetton } from '../wrappers/Jetton';
import { NetworkProvider } from '@ton/blueprint';
import { buildOnchainMetadata } from '../utils/jetton-helpers';

export async function run(provider: NetworkProvider) {
    const jettonParams = {
        name: "S5",
        description: "Elon musk will join Cypher to make ton a better place",
        symbol: "S5",
        image: "data:image/webp;base64,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",
    };

    // Create content Cell
    let content = buildOnchainMetadata(jettonParams);

    const sampleJetton = provider.open(await Jetton.fromInit(provider.sender().address as Address, content)); //1000000000000000000n

    await sampleJetton.send(
        provider.sender(),
        {
            value: toNano('0.05'),
        },
        {
            $$type: 'JettonMint',
            origin: provider.sender().address as Address,
            receiver: provider.sender().address as Address,
            amount: 100000000000000000n,
            custom_payload: null,
            forward_ton_amount: toNano('0.01'),
            forward_payload: beginCell().endCell().asSlice()
        }
    );

    await provider.waitForDeploy(sampleJetton.address);

    // run methods on `sampleJetton`
} 
