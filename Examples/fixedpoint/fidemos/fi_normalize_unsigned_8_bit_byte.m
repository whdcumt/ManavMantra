function [x,n] = fi_normalize_unsigned_8_bit_byte(u) %#codegen
%FI_NORMALIZE_UNSIGNED_8_BIT_BYTE Normalize to the range [1, 2)
%   [X,N] = FI_NORMALIZE_UNSIGNED_8_BIT_BYTE(U) normalizes the input U
%   such that the output X is
%
%       U = X*2^N
%       1 <= X < 2
%
%   The output X is unsigned with one integer bit.
%
%   The input U must be scalar and positive.
%
%   The number of bits in a byte is assumed to be B=8.

% Copyright 2012 The MathWorks, Inc.
    assert(isscalar(u),'Input must be scalar');
    assert(all(u>0),'Input must be positive.');
    assert(isfi(u) && isfixed(u),'Input must be a fi object with fixed-point data type.');
    u = removefimath(u);
    NLZLUT = number_of_leading_zeros_look_up_table();
    word_length = u.WordLength;
    u_fraction_length = u.FractionLength;
    B = 8;
    leftshifts=int8(0);
    % Reinterpret the input as an unsigned integer.
    T_unsigned_integer = numerictype(0, word_length, 0);
    v = reinterpretcast(u,T_unsigned_integer);
    F = fimath('OverflowAction','Wrap',...
               'RoundingMethod','Floor',...
               'SumMode','KeepLSB',...
               'SumWordLength',v.WordLength);
    v = setfimath(v,F);
    % Unroll the loop in generated code so there will be no branching.
    for k = coder.unroll(1:ceil(word_length/B))
        % For each iteration, see how many leading zeros are in the high
        % byte of V, and shift them out to the left. Continue with the
        % shifted V for as many bytes as it has.
        %
        % The index is the high byte of the input plus 1 to make it a
        % one-based index.
        index = int32(bitsra(v, word_length - B) + uint8(1));
        % Index into the number-of-leading-zeros lookup table.  This lookup
        % table takes in a byte and returns the number of leading zeros in the
        % binary representation.
        shiftamount = NLZLUT(index);
        % Left-shift out all the leading zeros in the high byte.
        v = bitsll(v,shiftamount);
        % Update the total number of left-shifts
        leftshifts = leftshifts+shiftamount;
    end
    % The input has been left-shifted so the most-significant-bit is a 1.
    % Reinterpret the output as unsigned with one integer bit, so
    % that 1 <= x < 2.
    T_x = numerictype(0,word_length,word_length-1);
    x = reinterpretcast(v, T_x);
    x = removefimath(x);
    % Let Q = int(u).  Then u = Q*2^(-u_fraction_length), 
    % and x = Q*2^leftshifts * 2^(1-word_length).  Therefore,
    % u = x*2^n, where n is defined as:
    n = word_length -  u_fraction_length - leftshifts - 1;
end

function NLZLUT = number_of_leading_zeros_look_up_table()
%   B = 8;  % Number of bits in a byte
%   NLZLUT = int8(B-ceil(log2((1:2^B))))
    NLZLUT = int8([8    7    6    6    5    5    5    5 ...
                   4    4    4    4    4    4    4    4 ...
                   3    3    3    3    3    3    3    3 ...
                   3    3    3    3    3    3    3    3 ...
                   2    2    2    2    2    2    2    2 ...
                   2    2    2    2    2    2    2    2 ...
                   2    2    2    2    2    2    2    2 ...
                   2    2    2    2    2    2    2    2 ...
                   1    1    1    1    1    1    1    1 ...
                   1    1    1    1    1    1    1    1 ...
                   1    1    1    1    1    1    1    1 ...
                   1    1    1    1    1    1    1    1 ...
                   1    1    1    1    1    1    1    1 ...
                   1    1    1    1    1    1    1    1 ...
                   1    1    1    1    1    1    1    1 ...
                   1    1    1    1    1    1    1    1 ...
                   0    0    0    0    0    0    0    0 ...
                   0    0    0    0    0    0    0    0 ...
                   0    0    0    0    0    0    0    0 ...
                   0    0    0    0    0    0    0    0 ...
                   0    0    0    0    0    0    0    0 ...
                   0    0    0    0    0    0    0    0 ...
                   0    0    0    0    0    0    0    0 ...
                   0    0    0    0    0    0    0    0 ...
                   0    0    0    0    0    0    0    0 ...
                   0    0    0    0    0    0    0    0 ...
                   0    0    0    0    0    0    0    0 ...
                   0    0    0    0    0    0    0    0 ...
                   0    0    0    0    0    0    0    0 ...
                   0    0    0    0    0    0    0    0 ...
                   0    0    0    0    0    0    0    0 ...
                   0    0    0    0    0    0    0    0]);
end