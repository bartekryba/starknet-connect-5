%lang starknet
from starkware.cairo.common.math_cmp import is_nn_le, is_le
from starkware.cairo.common.math import assert_not_equal, assert_nn_le
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

const PLAYER_1_MOVE = 0
const PLAYER_2_MOVE = 1
const PLAYER_1_WON = 2
const PLAYER_2_WON = 3

const SYMBOL_EMPTY = 0
const SYMBOL_PLAYER_1 = 1
const SYMBOL_PLAYER_2 = 2

struct BoardSize:
    member width : felt
    member height : felt
end

struct Game:
    member player1 : felt
    member player2 : felt
    member state : felt
end

@storage_var
func board_size() -> (board_size : BoardSize):
end

@storage_var
func board(x : felt, y : felt) -> (field : felt):
end

@storage_var
func current_game() -> (game : Game):
end

@view
func get_board{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    board_array_len : felt, board_array : felt*
):
    alloc_locals

    let (board : BoardSize) = board_size.read()
    let (array : felt*) = alloc()
    let array_len = board.width * board.height

    get_board_internal(board, 0, 0, array)

    return (array_len, array)
end

@view
func get_game{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (game: Game):
    let (current) = current_game.read()

    return (current)
end

func get_board_internal{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    board_size : BoardSize, x : felt, y : felt, array : felt*
):
    alloc_locals

    if y == board_size.height:
        return ()
    end

    let (current) = board.read(x, y)
    assert [array] = current

    let (next_column) = is_le(x, board_size.width - 2)

    if next_column == 1:
        return get_board_internal(board_size, x + 1, y, array + 1)
    end

    return get_board_internal(board_size, 0, y + 1, array + 1)
end

func is_in_board{range_check_ptr}(board_size : BoardSize, x : felt, y : felt) -> (in_board : felt):
    alloc_locals

    let (x_in_range) = is_nn_le(x, board_size.width - 1)
    let (y_in_range) = is_nn_le(y, board_size.height - 1)

    if (x_in_range + y_in_range) == 2:
        return (1)
    end

    return (0)
end

func assert_in_board{range_check_ptr}(board_size : BoardSize, x : felt, y : felt):
    let (in_board) = is_in_board(board_size, x, y)

    assert in_board = 1

    return ()
end

func assert_empty{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    x : felt, y : felt
):
    let (field) = board.read(x, y)

    assert field = SYMBOL_EMPTY

    return ()
end

func count_neighbours{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    player_symbol : felt, x : felt, y : felt, dx : felt, dy : felt, distance : felt
) -> (neighbours : felt):
    alloc_locals

    let (size) = board_size.read()
    let (in_board) = is_in_board(size, x, y)

    if in_board == 0:
        return (distance)
    end

    let (symbol) = board.read(x, y)

    if symbol != player_symbol:
        return (distance)
    end

    if distance == 4:
        return (distance)
    end

    return count_neighbours(player_symbol, x + dx, y + dy, dx, dy, distance + 1)
end

func is_winning_position{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    x : felt, y : felt, symbol : felt
) -> (winning_position : felt):
    alloc_locals

    let (n_neighbours) = count_neighbours(symbol, x, y - 1, 0, -1, 0)
    let (s_neighbours) = count_neighbours(symbol, x, y + 1, 0, 1, 0)

    let (is_winning) = is_le(4, n_neighbours + s_neighbours)
    if is_winning == 1:
        return (1)
    end

    let (e_neighbours) = count_neighbours(symbol, x - 1, y, -1, 0, 0)
    let (w_neighbours) = count_neighbours(symbol, x + 1, y, 1, 0, 0)

    let (is_winning) = is_le(4, e_neighbours + w_neighbours)
    if is_winning == 1:
        return (1)
    end

    let (ne_neighbours) = count_neighbours(symbol, x + 1, y - 1, 1, -1, 0)
    let (sw_neighbours) = count_neighbours(symbol, x - 1, y + 1, -1, 1, 0)

    let (is_winning) = is_le(4, ne_neighbours + sw_neighbours)
    if is_winning == 1:
        return (1)
    end

    let (nw_neighbours) = count_neighbours(symbol, x - 1, y - 1, -1, -1, 0)
    let (se_neighbours) = count_neighbours(symbol, x + 1, y + 1, 1, 1, 0)

    let (is_winning) = is_le(4, nw_neighbours + se_neighbours)
    if is_winning == 1:
        return (1)
    end

    return (0)
end

@external
func make_move{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    x : felt, y : felt
):
    alloc_locals

    let (game) = current_game.read()
    assert_nn_le(game.state, PLAYER_2_MOVE)

    let (player) = get_caller_address()

    local player_symbol : felt

    if game.state == PLAYER_1_MOVE:
        assert player = game.player1

        player_symbol = SYMBOL_PLAYER_1
    end

    if game.state == PLAYER_2_MOVE:
        assert player = game.player2

        player_symbol = SYMBOL_PLAYER_2
    end

    let (size) = board_size.read()
    assert_in_board(size, x, y)
    assert_empty(x, y)

    board.write(x, y, player_symbol)

    let (winning_position) = is_winning_position(x, y, player_symbol)

    if winning_position == 1:
        let new_game = Game(game.player1, game.player2, game.state + 2)
        current_game.write(new_game)

        return ()
    end

    let new_state = PLAYER_2_MOVE - game.state
    let new_game = Game(game.player1, game.player2, new_state)

    current_game.write(new_game)

    return ()
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    player1 : felt, player2 : felt, width : felt, height : felt
):
    assert_not_equal(player1, player2)

    let game = Game(player1=player1, player2=player2, state=PLAYER_1_MOVE)
    current_game.write(game)

    let size = BoardSize(width=width, height=height)
    board_size.write(size)

    return ()
end
