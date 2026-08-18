package com.bwoah07.kiminetworkplug;

import io.netty.buffer.ByteBuf;
import net.minecraft.core.BlockPos;
import net.minecraft.network.codec.ByteBufCodecs;
import net.minecraft.network.codec.StreamCodec;
import net.minecraft.network.protocol.common.custom.CustomPacketPayload;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.neoforged.neoforge.network.event.RegisterPayloadHandlersEvent;
import net.neoforged.neoforge.network.handling.IPayloadContext;
import net.neoforged.neoforge.network.registration.PayloadRegistrar;

public final class NetworkPlugNetworking {
    private NetworkPlugNetworking() {}

    public static void register(RegisterPayloadHandlersEvent event) {
        PayloadRegistrar registrar = event.registrar("2");
        registrar.playToServer(NetworkNamePayload.TYPE, NetworkNamePayload.STREAM_CODEC, NetworkPlugNetworking::handleNetworkName);
        registrar.playToServer(TransferLimitPayload.TYPE, TransferLimitPayload.STREAM_CODEC, NetworkPlugNetworking::handleTransferLimit);
        registrar.playToServer(ChargerConfigPayload.TYPE, ChargerConfigPayload.STREAM_CODEC, NetworkPlugNetworking::handleChargerConfig);
    }

    private static boolean validPlayerAndDistance(IPayloadContext context, BlockPos pos) {
        if (!(context.player() instanceof ServerPlayer player)) return false;
        return player.distanceToSqr(pos.getX() + 0.5, pos.getY() + 0.5, pos.getZ() + 0.5) <= 64.0;
    }

    private static void handleNetworkName(NetworkNamePayload payload, IPayloadContext context) {
        BlockPos pos = new BlockPos(payload.x(), payload.y(), payload.z());
        if (!validPlayerAndDistance(context, pos)) return;
        BlockEntity blockEntity = context.player().level().getBlockEntity(pos);
        if (blockEntity instanceof NetworkPlugBlockEntity plug) plug.setNetworkName(payload.name());
    }

    private static void handleTransferLimit(TransferLimitPayload payload, IPayloadContext context) {
        BlockPos pos = new BlockPos(payload.x(), payload.y(), payload.z());
        if (!validPlayerAndDistance(context, pos)) return;
        BlockEntity blockEntity = context.player().level().getBlockEntity(pos);
        if (blockEntity instanceof NetworkPlugBlockEntity plug) plug.setTransferLimit(payload.limit());
    }

    private static void handleChargerConfig(ChargerConfigPayload payload, IPayloadContext context) {
        BlockPos pos = new BlockPos(payload.x(), payload.y(), payload.z());
        if (!validPlayerAndDistance(context, pos)) return;
        BlockEntity blockEntity = context.player().level().getBlockEntity(pos);
        if (blockEntity instanceof WirelessChargerBlockEntity charger) {
            charger.applyClientConfig(payload.network(), payload.range(), payload.rate(), payload.inventory(), payload.armor(), payload.offhand(), payload.curios());
        }
    }

    public record NetworkNamePayload(int x, int y, int z, String name) implements CustomPacketPayload {
        public static final Type<NetworkNamePayload> TYPE = new Type<>(ResourceLocation.fromNamespaceAndPath(KimiNetworkPlug.MODID, "set_network_name"));
        public static final StreamCodec<ByteBuf, NetworkNamePayload> STREAM_CODEC = StreamCodec.composite(
                ByteBufCodecs.VAR_INT, NetworkNamePayload::x,
                ByteBufCodecs.VAR_INT, NetworkNamePayload::y,
                ByteBufCodecs.VAR_INT, NetworkNamePayload::z,
                ByteBufCodecs.STRING_UTF8, NetworkNamePayload::name,
                NetworkNamePayload::new);
        @Override public Type<? extends CustomPacketPayload> type() { return TYPE; }
    }

    public record TransferLimitPayload(int x, int y, int z, long limit) implements CustomPacketPayload {
        public static final Type<TransferLimitPayload> TYPE = new Type<>(ResourceLocation.fromNamespaceAndPath(KimiNetworkPlug.MODID, "set_transfer_limit"));
        public static final StreamCodec<ByteBuf, TransferLimitPayload> STREAM_CODEC = StreamCodec.composite(
                ByteBufCodecs.VAR_INT, TransferLimitPayload::x,
                ByteBufCodecs.VAR_INT, TransferLimitPayload::y,
                ByteBufCodecs.VAR_INT, TransferLimitPayload::z,
                ByteBufCodecs.VAR_LONG, TransferLimitPayload::limit,
                TransferLimitPayload::new);
        @Override public Type<? extends CustomPacketPayload> type() { return TYPE; }
    }

    public record ChargerConfigPayload(int x, int y, int z, String network, int range, long rate,
                                       boolean inventory, boolean armor, boolean offhand, boolean curios) implements CustomPacketPayload {
        public static final Type<ChargerConfigPayload> TYPE = new Type<>(ResourceLocation.fromNamespaceAndPath(KimiNetworkPlug.MODID, "charger_config"));
        public static final StreamCodec<ByteBuf, ChargerConfigPayload> STREAM_CODEC = StreamCodec.composite(
                ByteBufCodecs.VAR_INT, ChargerConfigPayload::x,
                ByteBufCodecs.VAR_INT, ChargerConfigPayload::y,
                ByteBufCodecs.VAR_INT, ChargerConfigPayload::z,
                ByteBufCodecs.STRING_UTF8, ChargerConfigPayload::network,
                ByteBufCodecs.VAR_INT, ChargerConfigPayload::range,
                ByteBufCodecs.VAR_LONG, ChargerConfigPayload::rate,
                ByteBufCodecs.BOOL, ChargerConfigPayload::inventory,
                ByteBufCodecs.BOOL, ChargerConfigPayload::armor,
                ByteBufCodecs.BOOL, ChargerConfigPayload::offhand,
                ByteBufCodecs.BOOL, ChargerConfigPayload::curios,
                ChargerConfigPayload::new);
        @Override public Type<? extends CustomPacketPayload> type() { return TYPE; }
    }
}
