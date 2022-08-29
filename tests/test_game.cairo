%lang starknet
from src.game import BoardSize, is_in_board, get_board
from starkware.cairo.common.cairo_builtins import HashBuiltin

@contract_interface
namespace GameContract:
    func get_board() -> (board_len: felt, board: felt*):
    end
end

@external
func test_is_in_board{
    syscall_ptr : felt*, range_check_ptr, pedersen_ptr : HashBuiltin*
}():
    alloc_locals
    local contract_address

    let board_size = BoardSize(width = 8, height = 10)

    let (test1) = is_in_board(board_size, 0, 0)
    assert test1 = 1

    let (test2) = is_in_board(board_size, 7, 4)
    assert test2 = 1

    let (test3) = is_in_board(board_size, 9, 2)
    assert test3 = 0

    let (test4) = is_in_board(board_size, 5, -3)
    assert test4 = 0

    let (test5) = is_in_board(board_size, 12, 14)
    assert test5 = 0

    let (test6) = is_in_board(board_size, -4, -3)
    assert test6 = 0

    return ()
end

@external
func test_constructor{
    syscall_ptr : felt*, range_check_ptr, pedersen_ptr : HashBuiltin*
}():
    alloc_locals

    %{
        ids.contract_address = deploy_contract("./src/game.cairo", [100, 120, 5, 4]).contract_address

        board_size = load(ids.contract_address, "board_size", "BoardSize")
        assert board_size == [5, 4]

        current_game = load(ids.contract_address, "current_game", "Game")
    %}
end

@external
func test_read_board{
    syscall_ptr : felt*, range_check_ptr, pedersen_ptr : HashBuiltin*
}():
    alloc_locals
    local contract_address

    %{
        ids.contract_address = deploy_contract("./src/game.cairo", [100, 100, 5, 4]).contract_address
        store(ids.contract_address, "board", [1], key=[3, 0])
        store(ids.contract_address, "board", [1], key=[1, 1])
        store(ids.contract_address, "board", [1], key=[4, 3])
        store(ids.contract_address, "board", [2], key=[2, 2])
        store(ids.contract_address, "board", [2], key=[3, 2])
    %}

    let (board_len, board) = GameContract.get_board(contract_address=contract_address)

    assert board_len = 20

    %{
        expected = [
            0, 0, 0, 1, 0,
            0, 1, 0, 0, 0,
            0, 0, 2, 2, 0,
            0, 0, 0, 0, 1
        ]

        for i, value in enumerate(expected):
            assert memory[ids.board + i] == value
    %}

    return ()
end
