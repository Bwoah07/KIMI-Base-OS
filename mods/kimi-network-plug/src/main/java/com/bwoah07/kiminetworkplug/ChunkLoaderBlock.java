package com.bwoah07.kiminetworkplug;

import com.mojang.serialization.MapCodec;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.VoxelShape;

public final class ChunkLoaderBlock extends Block {
    public static final MapCodec<ChunkLoaderBlock> CODEC = simpleCodec(ChunkLoaderBlock::new);
    private static final VoxelShape SHAPE = Block.box(3, 0, 3, 13, 3.75, 13);

    public ChunkLoaderBlock(BlockBehaviour.Properties properties) { super(properties); }
    @Override protected MapCodec<? extends Block> codec() { return CODEC; }
    @Override protected VoxelShape getShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext context) { return SHAPE; }
    @Override protected VoxelShape getCollisionShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext context) { return SHAPE; }

    @Override
    protected void onPlace(BlockState state, Level level, BlockPos pos, BlockState oldState, boolean movedByPiston) {
        super.onPlace(state, level, pos, oldState, movedByPiston);
        if (!level.isClientSide && !oldState.is(this) && level instanceof ServerLevel serverLevel) {
            ChunkLoadingSavedData.register(serverLevel, pos);
        }
    }

    @Override
    protected void onRemove(BlockState state, Level level, BlockPos pos, BlockState newState, boolean movedByPiston) {
        if (!level.isClientSide && !newState.is(this) && level instanceof ServerLevel serverLevel) {
            ChunkLoadingSavedData.unregister(serverLevel, pos);
        }
        super.onRemove(state, level, pos, newState, movedByPiston);
    }

    public static boolean isEnabled(ServerLevel level, BlockPos pos) {
        return ChunkLoadingSavedData.isRegistered(level, pos);
    }

    public static void setEnabled(ServerLevel level, BlockPos pos, boolean enabled) {
        if (!level.getBlockState(pos).is(KimiNetworkPlug.CHUNK_LOADER.get())) return;
        if (enabled) ChunkLoadingSavedData.register(level, pos);
        else ChunkLoadingSavedData.unregister(level, pos);
    }

    @Override
    protected InteractionResult useWithoutItem(BlockState state, Level level, BlockPos pos, Player player, BlockHitResult hit) {
        if (!level.isClientSide && level instanceof ServerLevel serverLevel) {
            boolean enabled = isEnabled(serverLevel, pos);
            player.displayClientMessage(Component.literal(
                    "KIMI Chunk Loader " + (enabled ? "ON" : "OFF") + " | chunk " + (pos.getX() >> 4) + ", " + (pos.getZ() >> 4)
            ), true);
        }
        return InteractionResult.sidedSuccess(level.isClientSide);
    }
}
