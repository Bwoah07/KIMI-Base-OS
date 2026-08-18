package com.bwoah07.kiminetworkplug;

import com.mojang.serialization.MapCodec;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.MenuProvider;
import net.minecraft.world.SimpleMenuProvider;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.context.BlockPlaceContext;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.EntityBlock;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.entity.BlockEntityTicker;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.level.block.state.properties.DirectionProperty;
import net.minecraft.world.level.block.state.properties.EnumProperty;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;
import org.jetbrains.annotations.Nullable;

public final class NetworkPlugBlock extends Block implements EntityBlock {
    public static final MapCodec<NetworkPlugBlock> CODEC = simpleCodec(NetworkPlugBlock::new);
    public static final EnumProperty<PlugMode> MODE = EnumProperty.create("mode", PlugMode.class);
    public static final DirectionProperty FACING = BlockStateProperties.FACING;

    // A small Flux-style connector: 8x8 body + a thin mounting plate on the block face.
    private static final VoxelShape NORTH_SHAPE = Shapes.or(
            Block.box(3, 3, 14, 13, 13, 16),
            Block.box(4, 4, 9, 12, 12, 14),
            Block.box(5, 5, 8, 11, 11, 9)
    );
    private static final VoxelShape SOUTH_SHAPE = Shapes.or(
            Block.box(3, 3, 0, 13, 13, 2),
            Block.box(4, 4, 2, 12, 12, 7),
            Block.box(5, 5, 7, 11, 11, 8)
    );
    private static final VoxelShape WEST_SHAPE = Shapes.or(
            Block.box(14, 3, 3, 16, 13, 13),
            Block.box(9, 4, 4, 14, 12, 12),
            Block.box(8, 5, 5, 9, 11, 11)
    );
    private static final VoxelShape EAST_SHAPE = Shapes.or(
            Block.box(0, 3, 3, 2, 13, 13),
            Block.box(2, 4, 4, 7, 12, 12),
            Block.box(7, 5, 5, 8, 11, 11)
    );
    private static final VoxelShape UP_SHAPE = Shapes.or(
            Block.box(3, 0, 3, 13, 2, 13),
            Block.box(4, 2, 4, 12, 7, 12),
            Block.box(5, 7, 5, 11, 8, 11)
    );
    private static final VoxelShape DOWN_SHAPE = Shapes.or(
            Block.box(3, 14, 3, 13, 16, 13),
            Block.box(4, 9, 4, 12, 14, 12),
            Block.box(5, 8, 5, 11, 9, 11)
    );

    public NetworkPlugBlock(BlockBehaviour.Properties properties) {
        super(properties);
        registerDefaultState(stateDefinition.any()
                .setValue(MODE, PlugMode.DISABLED)
                .setValue(FACING, Direction.NORTH));
    }

    @Override
    protected MapCodec<? extends Block> codec() {
        return CODEC;
    }

    @Override
    protected void createBlockStateDefinition(StateDefinition.Builder<Block, BlockState> builder) {
        builder.add(MODE, FACING);
    }

    @Override
    public @Nullable BlockState getStateForPlacement(BlockPlaceContext context) {
        return defaultBlockState().setValue(FACING, context.getClickedFace());
    }

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
            BlockEntity blockEntity = level.getBlockEntity(pos);
            if (blockEntity instanceof NetworkPlugBlockEntity plug) {
                PowerNetworkSavedData.get(serverLevel).unregisterPlug(plug.getPlugId());
            }
            ChunkLoadingSavedData.unregister(serverLevel, pos);
        }
        super.onRemove(state, level, pos, newState, movedByPiston);
    }

    @Override
    public @Nullable MenuProvider getMenuProvider(BlockState state, Level level, BlockPos pos) {
        BlockEntity blockEntity = level.getBlockEntity(pos);
        if (!(blockEntity instanceof NetworkPlugBlockEntity plug)) return null;

        return new SimpleMenuProvider(
                (containerId, inventory, player) -> new NetworkPlugMenu(containerId, inventory, plug),
                Component.literal("KIMI Network Plug")
        );
    }

    @Override
    protected InteractionResult useWithoutItem(BlockState state, Level level, BlockPos pos, Player player, BlockHitResult hit) {
        if (!level.isClientSide && player instanceof ServerPlayer serverPlayer) {
            MenuProvider provider = getMenuProvider(state, level, pos);
            if (provider != null) serverPlayer.openMenu(provider);
        }
        return InteractionResult.sidedSuccess(level.isClientSide);
    }

    @Override
    protected VoxelShape getShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext context) {
        return shapeFor(state.getValue(FACING));
    }

    @Override
    protected VoxelShape getCollisionShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext context) {
        return shapeFor(state.getValue(FACING));
    }

    private static VoxelShape shapeFor(Direction direction) {
        return switch (direction) {
            case NORTH -> NORTH_SHAPE;
            case SOUTH -> SOUTH_SHAPE;
            case WEST -> WEST_SHAPE;
            case EAST -> EAST_SHAPE;
            case UP -> UP_SHAPE;
            case DOWN -> DOWN_SHAPE;
        };
    }

    @Override
    public RenderShape getRenderShape(BlockState state) {
        return RenderShape.MODEL;
    }

    @Override
    public @Nullable BlockEntity newBlockEntity(BlockPos pos, BlockState state) {
        return new NetworkPlugBlockEntity(pos, state);
    }

    @Override
    public <T extends BlockEntity> @Nullable BlockEntityTicker<T> getTicker(
            Level level,
            BlockState state,
            BlockEntityType<T> type
    ) {
        if (level.isClientSide) return null;
        return createTicker(type, KimiNetworkPlug.NETWORK_PLUG_BLOCK_ENTITY.get(), NetworkPlugBlockEntity::serverTick);
    }

    @SuppressWarnings("unchecked")
    private static <E extends BlockEntity, A extends BlockEntity> @Nullable BlockEntityTicker<A> createTicker(
            BlockEntityType<A> actualType,
            BlockEntityType<E> expectedType,
            BlockEntityTicker<? super E> ticker
    ) {
        return actualType == expectedType ? (BlockEntityTicker<A>) ticker : null;
    }
}
