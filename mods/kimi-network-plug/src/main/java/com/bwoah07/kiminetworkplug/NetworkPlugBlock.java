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

    // Alpha.10: the head deliberately fills most of the selected block space while
    // the machine-facing plate and neck remain compact, matching the visual model.
    private static final VoxelShape NORTH_SHAPE = Shapes.or(
            Block.box(5.25, 5.25, 14.5, 10.75, 10.75, 16),
            Block.box(6.25, 6.25, 11.75, 9.75, 9.75, 14.5),
            Block.box(2.75, 2.75, 4.0, 13.25, 13.25, 11.75)
    );
    private static final VoxelShape SOUTH_SHAPE = Shapes.or(
            Block.box(5.25, 5.25, 0, 10.75, 10.75, 1.5),
            Block.box(6.25, 6.25, 1.5, 9.75, 9.75, 4.25),
            Block.box(2.75, 2.75, 4.25, 13.25, 13.25, 12.0)
    );
    private static final VoxelShape WEST_SHAPE = Shapes.or(
            Block.box(14.5, 5.25, 5.25, 16, 10.75, 10.75),
            Block.box(11.75, 6.25, 6.25, 14.5, 9.75, 9.75),
            Block.box(4.0, 2.75, 2.75, 11.75, 13.25, 13.25)
    );
    private static final VoxelShape EAST_SHAPE = Shapes.or(
            Block.box(0, 5.25, 5.25, 1.5, 10.75, 10.75),
            Block.box(1.5, 6.25, 6.25, 4.25, 9.75, 9.75),
            Block.box(4.25, 2.75, 2.75, 12.0, 13.25, 13.25)
    );
    private static final VoxelShape UP_SHAPE = Shapes.or(
            Block.box(5.25, 0, 5.25, 10.75, 1.5, 10.75),
            Block.box(6.25, 1.5, 6.25, 9.75, 4.25, 9.75),
            Block.box(2.75, 4.25, 2.75, 13.25, 12.0, 13.25)
    );
    private static final VoxelShape DOWN_SHAPE = Shapes.or(
            Block.box(5.25, 14.5, 5.25, 10.75, 16, 10.75),
            Block.box(6.25, 11.75, 6.25, 9.75, 14.5, 9.75),
            Block.box(2.75, 4.0, 2.75, 13.25, 11.75, 13.25)
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
