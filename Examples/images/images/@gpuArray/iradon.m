function [img,H] = iradon(varargin)
%IRADON Inverse Radon transform.
%   I = iradon(R,THETA) reconstructs the image I from projection data in
%   the 2-D gpuArray R.  The columns of R are parallel beam projection
%   data. IRADON assumes that the center of rotation is the center point of
%   the projections, which is defined as ceil(size(R,1)/2).
%
%   THETA describes the angles (in degrees) at which the projections were
%   taken.  It can be either a vector (or gpuArray vector) containing the
%   angles or a scalar specifying D_theta, the incremental angle between
%   projections. If THETA is a vector, it must contain angles with equal
%   spacing between them.  If THETA is a scalar specifying D_theta, the
%   projections are taken at angles THETA = m * D_theta; m =
%   0,1,2,...,size(R,2)-1.  If the input is the empty matrix ([]), D_theta
%   defaults to 180/size(R,2).
%
%   IRADON uses the filtered backprojection algorithm to perform the inverse
%   Radon transform.  The filter is designed directly in the frequency
%   domain and then multiplied by the FFT of the projections.  The
%   projections are zero-padded to a power of 2 before filtering to prevent
%   spatial domain aliasing and to speed up the FFT.
%
%   I = IRADON(R,THETA,INTERPOLATION,FILTER,FREQUENCY_SCALING,OUTPUT_SIZE)
%   specifies parameters to use in the inverse Radon transform.  You can
%   specify any combination of the last four arguments.  IRADON uses default
%   values for any of these arguments that you omit.
%
%   INTERPOLATION specifies the type of interpolation to use in the
%   backprojection. The default is linear interpolation. Available methods
%   are:
%
%      'nearest' - nearest neighbor interpolation
%      'linear'  - linear interpolation (default)
%
%   FILTER specifies the filter to use for frequency domain filtering.
%   FILTER is a string or a character vector that specifies any of the
%   following standard filters:
%
%   'Ram-Lak'     The cropped Ram-Lak or ramp filter (default).  The
%                 frequency response of this filter is |f|.  Because this
%                 filter is sensitive to noise in the projections, one of
%                 the filters listed below may be preferable.
%   'Shepp-Logan' The Shepp-Logan filter multiplies the Ram-Lak filter by
%                 a sinc function.
%   'Cosine'      The cosine filter multiplies the Ram-Lak filter by a
%                 cosine function.
%   'Hamming'     The Hamming filter multiplies the Ram-Lak filter by a
%                 Hamming window.
%   'Hann'        The Hann filter multiplies the Ram-Lak filter by a
%                 Hann window.
%   'none'        No filtering is performed.
%
%   FREQUENCY_SCALING is a scalar in the range (0,1] that modifies the
%   filter by rescaling its frequency axis.  The default is 1.  If
%   FREQUENCY_SCALING is less than 1, the filter is compressed to fit into
%   the frequency range [0,FREQUENCY_SCALING], in normalized frequencies;
%   all frequencies above FREQUENCY_SCALING are set to 0.
%
%   OUTPUT_SIZE is a scalar that specifies the number of rows and columns in
%   the reconstructed image.  If OUTPUT_SIZE is not specified, the size is
%   determined from the length of the projections:
%
%       OUTPUT_SIZE = 2*floor(size(R,1)/(2*sqrt(2)))
%
%   If you specify OUTPUT_SIZE, IRADON reconstructs a smaller or larger
%   portion of the image, but does not change the scaling of the data.
%
%   If the projections were calculated with the RADON function, the
%   reconstructed image may not be the same size as the original image.
%
%   [I,H] = iradon(...) returns the frequency response of the filter in the
%   vector H.
%
%   Class Support
%   -------------
%   R can be a gpuArray of underlying class double or single. All other
%   numeric input arguments must be double or gpuArray of underlying class
%   double. I has the same class as R. H is a gpuArray of underlying class
%   double.
%
%   Notes
%   -----
%   The GPU implementation of this function supports only nearest neighbor
%   and linear interpolation methods for the backprojection. 
%
%   Examples
%   --------
%   Compare filtered and unfiltered backprojection.
%
%       P = gpuArray(phantom(128));
%       R = radon(P,0:179);
%       I1 = iradon(R,0:179);
%       I2 = iradon(R,0:179,'linear','none');
%       subplot(1,3,1), imshow(P), title('Original')
%       subplot(1,3,2), imshow(I1), title('Filtered backprojection')
%       subplot(1,3,3), imshow(I2,[]), title('Unfiltered backprojection')
%
%   Compute the backprojection of a single projection vector. The IRADON
%   syntax does not allow you to do this directly, because if THETA is a
%   scalar it is treated as an increment.  You can accomplish the task by
%   passing in two copies of the projection vector and then dividing the
%   result by 2.
%
%       P = gpuArray(phantom(128));
%       R = radon(P,0:179);
%       r45 = R(:,46);
%       I = iradon([r45 r45], [45 45])/2;
%       imshow(I, [])
%       title('Backprojection from the 45-degree projection')
%
%   See also FAN2PARA, FANBEAM, IFANBEAM, PARA2FAN, PHANTOM,
%            GPUARRAY/RADON,GPUARRAY.

%   Copyright 2013-2017 The MathWorks, Inc.

%   References:
%      A. C. Kak, Malcolm Slaney, "Principles of Computerized Tomographic
%      Imaging", IEEE Press 1988.

narginchk(2,6);

args = matlab.images.internal.stringToChar(varargin);
%Dispatch to CPU if needed.
if ~isa(args{1},'gpuArray')
    args = gatherIfNecessary(args{:});
    [img,H] = iradon(args{:});
    return;
end

[p,theta,filter,d,interp,N] = parse_inputs(args{:});

[p,H] = filterProjections(p, filter, d);

% Zero pad the projections to size 1+2*ceil(N/sqrt(2)) if this
% quantity is greater than the length of the projections
imgDiag = 2*ceil(N/sqrt(2))+1;  % largest distance through image.
if size(p,1) < imgDiag
    rz = imgDiag - size(p,1);  % how many rows of zeros
    top = gpuArray.zeros(ceil(rz/2),size(p,2));
    bot = gpuArray.zeros(floor(rz/2),size(p,2));
    p = [top; p; bot];
end

% Backprojection
switch interp
    case 'nearest neighbor'
        img = images.internal.gpu.iradon(N, theta, p, false);

    case 'linear'
        img = images.internal.gpu.iradon(N, theta, p, true);
end


%======================================================================
function [p,H] = filterProjections(p, filter, d)

% Design the filter
len = size(p,1);
H = designFilter(filter, len, d);

if strcmpi(filter, 'none')
    return;
end

% faster to put padding directly into FFT below
% p(length(H),1)=0;  % Zero pad projections

% In the code below, I continuously reuse the array p so as to
% save memory.  This makes it harder to read, but the comments
% explain what is going on.

p = fft(p,length(H));  % p holds fft of projections

% for i = 1:size(p,2)
%     p(:,i) = p(:,i).*H; % frequency domain filtering
% end
p = bsxfun(@times, p, H); % faster than for-loop

p = ifft(p,'symmetric');

% p = p(1:len,:) % MCOS overload issue so directly form subsref
p = subsref(p,substruct('()', {1:len ':'}));
%----------------------------------------------------------------------

%======================================================================
function filt = designFilter(filter, len, d)
% Returns the Fourier Transform of the filter which will be
% used to filter the projections
%
% INPUT ARGS:   filter - either the string specifying the filter
%               len    - the length of the projections
%               d      - the fraction of frequencies below the nyquist
%                        which we want to pass
%
% OUTPUT ARGS:  filt   - the filter to use on the projections


order = max(64,2^nextpow2(2*len));

if strcmpi(filter, 'none')
    filt = ones(1, order);
    return;
end

% First create a bandlimited ramp filter (Eqn. 61 Chapter 3, Kak and
% Slaney) - go up to the next highest power of 2.

n = 0:(order/2); % 'order' is always even.
filtImpResp = zeros(1,(order/2)+1); % 'filtImpResp' is the bandlimited ramp's impulse response (values for even n are 0)
filtImpResp(1) = 1/4; % Set the DC term
filtImpResp(2:2:end) = -1./((pi*n(2:2:end)).^2); % Set the values for odd n
filtImpResp = [filtImpResp filtImpResp(end-1:-1:2)];
filt = 2*real(fft(filtImpResp));
filt = filt(1:(order/2)+1);

w = 2*pi*(0:size(filt,2)-1)/order;   % frequency axis up to Nyquist

switch filter
    case 'ram-lak'
        % Do nothing
    case 'shepp-logan'
        % be careful not to divide by 0:
        filt(2:end) = filt(2:end) .* (sin(w(2:end)/(2*d))./(w(2:end)/(2*d)));
    case 'cosine'
        filt(2:end) = filt(2:end) .* cos(w(2:end)/(2*d));
    case 'hamming'
        filt(2:end) = filt(2:end) .* (.54 + .46 * cos(w(2:end)/d));
    case 'hann'
        filt(2:end) = filt(2:end) .*(1+cos(w(2:end)./d)) / 2;
    otherwise
        error(message('images:iradon:invalidFilter'))
end

filt(w>pi*d) = 0;                      % Crop the frequency response
filt = [filt' ; filt(end-1:-1:2)'];    % Symmetry of the filter
%----------------------------------------------------------------------


%======================================================================
function [p,theta,filter,d,interp,N] = parse_inputs(varargin)
%  Parse the input arguments and return things
%
%  Inputs:   varargin -   Cell array containing all of the actual inputs
%
%  Outputs:  p        -   Projection data
%            theta    -   the angles at which the projections were taken
%            filter   -   string specifying filter or the actual filter
%            d        -   a scalar specifying normalized freq. at which to crop
%                         the frequency response of the filter
%            interp   -   the type of interpolation to use
%            N        -   The size of the reconstructed image

p     = varargin{1};
theta = gather(varargin{2});

hValidateAttributes(p,{'single','double'},{'real','2d','nonsparse'},...
                    mfilename,'R',1);
validateattributes (theta,{'double'},{'real','nonsparse'},...
                    mfilename,'theta',2);

% Convert to radians
theta = pi*theta/180;

% Default values
N = 0;                 % Size of the reconstructed image
d = 1;                 % Defaults to no cropping of filters frequency response
filter = 'ram-lak';    % The ramp filter is the default
interp = 'linear';     % default interpolation is linear

interp_strings = {'nearest neighbor', 'linear'};
filter_strings = {'ram-lak','shepp-logan','cosine','hamming', 'hann', 'none'};
string_args = [interp_strings filter_strings];

for i=3:nargin
    arg = gather(varargin{i});
    if ischar(arg)
        str = validatestring(arg,string_args,mfilename,'interpolation or filter');
        idx = find(strcmp(str,string_args),1,'first');
        if idx <= numel(interp_strings)
            % interpolation method
            interp = string_args{idx};
        else %if (idx > numel(interp_strings)) && (idx <= numel(string_args))
            % filter type
            filter = string_args{idx};
        end
    elseif numel(arg)==1
        if arg <=1
            % frequency scale
            validateattributes(arg,{'numeric','logical'},...
                {'positive','real','nonsparse'},...
                mfilename,'frequency_scaling');
            d = arg;
        else
            % output size
            validateattributes(arg,{'numeric'},...
                {'real','finite','nonsparse','integer'},...
                mfilename,'output_size');
            N = arg;
        end
    else
        error(message('images:iradon:invalidInputParameters'))
    end
end

% If the user didn't specify the size of the reconstruction, so
% deduce it from the length of projections
if N==0
    N = 2*floor( size(p,1)/(2*sqrt(2)) );  % This doesn't always jive with RADON
end

% for empty theta, choose an intelligent default delta-theta
if isempty(theta)
    theta = pi / size(p,2);  % TODO convert to degrees
end

% If the user passed in delta-theta, build the vector of theta values
if numel(theta)==1
    theta = (0:(size(p,2)-1))* theta; % TODO radian conversion
end

if length(theta) ~= size(p,2)
    error(message('images:iradon:thetaNotMatchingProjectionNumber'))
end
%----------------------------------------------------------------------
