function tnd = split(t,node,x,varargin)
%SPLIT Split (decompose) the data of a terminal node.
%   TNDATA = SPLIT(T,N,X) decomposes the data X 
%   associated to the terminal node N of the 
%   wavelet tree T.
%
%   TNDATA is a cell array (ORDER x 1) such that
%   TNDATA{k} contains the data associated to
%   the k-th child of N.
%
%   The method uses DWT (respectively DWT2) for
%   one-dimensional (respectively two-dimensional) data.
%
%   This method overloads the WTREE method.

%   M. Misiti, Y. Misiti, G. Oppenheim, J.M. Poggi 09-Sep-1999.
%   Last Revision: 15-May-2003.
%   Copyright 1995-2004 The MathWorks, Inc.

[order,dwtMode,Lo_D,Hi_D] = getwtbo(t,'order','dwtMode','Lo_D','Hi_D');
tnd = cell(order,1);
switch order
  case 2
    [tnd{2},tnd{1}] = dwt(x,Lo_D,Hi_D,'mode',dwtMode,'shift',0);
  case 4
    [tnd{4},tnd{1},tnd{2},tnd{3}] = ...
        dwt2(x,Lo_D,Hi_D,'mode',dwtMode,'shift',[0 0]);
end
