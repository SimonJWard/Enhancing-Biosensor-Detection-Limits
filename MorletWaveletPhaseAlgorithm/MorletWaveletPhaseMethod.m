%%
%% Morlet Wavelet Phase Method
%%
% This application implements the Morlet Wavelet Phase algorithm, developed
% primarily to measure frequency changes of Fabry Perot fringes in thin film
% optical reflectance spectra, to enable low limits of detection for optical
% thin film sensors. However, it can be used in any application where low
% noise measurement of frequency changes of an approximately sinusoidal
% signal are required. If you use this application, please cite the following
% paper which introduced the algorithm:
% 
% S. J. Ward, R. Layouni, S. Arshavsky-Graham, E. Segal, and S. M. Weiss,
% "Morlet Wavelet Filtering and Phase Analysis to Reduce the Limit of Detection
% for Thin Film Optical Biosensors,” ACS Sensors 6,  2967-2978 (2021).
%
% INSTRUCTIONS:
%Choose Wavelength Range of spectra to analyse (eg. 500nm - 800nm), enter
%into LowerLambdaBound and UpperLambdaBound. Enter index of spectra to use
%as reference (eg. 5 for the 5th spectra when alphanumerically ordered),
%enter ReferenceIndex. If there is a need to choose certain spectra files,
%enter common string of text in filename between ** in AllSpectraFiles (eg.
%if all spectra with "Exp" in the name should be analysed, *Exp*.txt). If
%all spectra are to be analysed AllSpectraFiles can be left as **.txt. To
%speed up the analysis, a minimum and maximum estimate for effective optical
%thickness (EOT), equal to 2nL (nm*RIU), can be provided by setting the
%variables LowerBoundEOTEstimate and UpperBoundEOTEstimate. This optional,
%but if used the film EOT must lie in this range. Wavelet parameters,
%FFT resolution and resolution in k-sace can also be optimized for a given
%measurement setup, but this is also optional. The result for each spectra
%is displayed, and stored in the Morlet Wavelet Phase (MWP) variable.
%
%Parameters:
%   *LowerLambdaBound: lower wavelength bound of the chosen spectral range
%    eg. 500nm (double)
%   *UpperLambdaBound: upper wavelength bound of the chosen spectral range
%    eg. 800nm (double)
%   *LowerBoundEOTEstimate: Lower bound for the estimated effective optical
%    thickness (2nL, where n is refractive index in RIU and L is thickness
%    in nm) of the thin film eg. 8000nm*RIU (double)
%   *UpperBoundEOTEstimate: Upper bound for the estimated effective optical
%    thickness (2nL, where n is refractive index in RIU and L is thickness
%    in nm) of the thin film eg. 20000nm*RIU (double)
%   *ReferenceIndex: Index of spectra file in alphanumerically sorted
%    spectra files in the current folder location chosen as the reference.
%    A baseline spectra in control solution. (int)
%Return:
%   *MWP: vector containing Morlet Wavelet Phase result for each of the N spectra files in
%   the current folder location (Ndarray)
%
%%
clear

%% User selected parameters
% -------------------------

LowerLambdaBound = 450;     %Lower bound of chosen spectral range with sufficient S/N (nm)
UpperLambdaBound = 900;       %Upper bound of chosen spectral range with sufficient S/N (nm)
LowerBoundEOTEstimate = 8000;     %OPTIONAL - Specify a lower bound to the expected 2nL value (um*RIU), to speed up search for peak 2nL
UpperBoundEOTEstimate = 20000;    %OPTIONAL - Specify a upper bound to the expected 2nL value (um*RIU), to speed up search for peak 2nL
AllSpectraFiles = dir('**\*P*.txt');              %Get all .txt files beginning with the string between the **. For example, '*Experiment*.txt' would fetch all .txt files beginning with "Experiment". If a single spectra is analyzed only the filename is needed, without any ** 
DataFolder = "Data\";      %Folder containing experimentally measured spectra .txt files
ReferenceFilename = 'P00000.txt';      %Specify reference spectra filename

%%% OPTIONAL - Parameters which can be optimized

kstep = 2E-7;          %Desired resolution in k-space used for interpolation of spectra
WaveletLength = 0.01;      %Length of wavelet in k-space
FFTZeroPaddingMultiplier = 2048;        %Multipler to increase zero padding for FFT

%% Initialization
% --------------

%%% Initialize wavenumber 
Desiredk = 1/UpperLambdaBound:kstep:1/LowerLambdaBound;        %Equally spaced k values for spectra interpolation
Waveletk  = -WaveletLength/2:kstep:WaveletLength/2;     %Wavelet k values

%%% Get all .txt file spectrum filenames in current folder
[~, SortedIndex]=sort({AllSpectraFiles.name});        %Index of alphanumerically sorted spectra files
AllSpectraFiles=AllSpectraFiles(SortedIndex);                       %Use index to alphanumerically sort spectra files

%%% Load and preprocess reference spectrum
disp(['Reference Spectra Filename is ' ReferenceFilename]);        %Print reference spectra filename
RefRInterpolated = ReadSpectrum((DataFolder + ReferenceFilename), Desiredk);

%%% Initialize frequency range and resolution for fourier transform
n = FFTZeroPaddingMultiplier*2^nextpow2(length(RefRInterpolated));      %Number of data points for all FFTs, determines resolution in frequency space 
frequency = (1/kstep)*(0:(n/2))/n;      %Points in frequency space
ReducedFrequencyRange = find(frequency>LowerBoundEOTEstimate & frequency<UpperBoundEOTEstimate);     %Find a reduced frequency range, between the lower and upper bounds that the 2nL value is guaranteed to be within
frequency = frequency(ReducedFrequencyRange);        %Cut down frequency range using estimated upper and lower frequency bouns

%%% Constant factor to convert between average phase and EOT (nm*RIU)
PhaseToEOTConversion = 0.0105003306;

%% Reference FFT
% --------------

[FWHMRef, DominantFrequencyRef] = FastFourierTransform(RefRInterpolated, n, ReducedFrequencyRange, frequency);

%% Reference Windowed FFT
% -----------------------

RefRInterpolatedWindow = RefRInterpolated.*hann(length(RefRInterpolated),'periodic')';
[FWHMRefWindow, DominantFrequencyRefWindow] = FastFourierTransform(RefRInterpolatedWindow, n, ReducedFrequencyRange, frequency);

%% Reference Morlet Wavelet
% -------------------------
WaveletFilteredRef = WaveletTransform(DominantFrequencyRef, Waveletk, FWHMRef, RefRInterpolated);

for i = 1:size(AllSpectraFiles,1)       %Iterate over all spectra files
    
    AnalyteFilename = AllSpectraFiles(i).name;
    AnalyteRInterpolated = ReadSpectrum((DataFolder + AnalyteFilename), Desiredk);
    
    %% Analyte FFT
    % ------------
    
    [HWHM, DominantFrequencyAnalyte] = FastFourierTransform(AnalyteRInterpolated, n, ReducedFrequencyRange, frequency);
    
    %% Analyte Windowed FFT
    % ---------------------

    AnalyteRInterpolatedWindow = AnalyteRInterpolated.*hann(length(AnalyteRInterpolated),'periodic')';
    [HWHMWindow, DominantFrequencyAnalyteWindow] = FastFourierTransform(AnalyteRInterpolatedWindow, n, ReducedFrequencyRange, frequency);
    
    %% Analyte Complex Morlet Wavelet
    % -------------------------------
    WaveletFilteredR = WaveletTransform(DominantFrequencyAnalyte, Waveletk, HWHM, AnalyteRInterpolated);

    %% Morlet Wavelet Phase Result
    % ----------------------------
    
    %Extract unwrapped phase from complex Morlet wavelet filtered spectra
    RefAngle = unwrap(angle(WaveletFilteredRef));      %Unwrapped phase from filtered reference spectra
    AnalyteAngle = unwrap(angle(WaveletFilteredR));      %Unwrapped phase from filtered ith spectra
    
    %Ensure that the starting phase (RefAngle(1) and
    %AnalyteAngle(1) are in the correct cycle relative to eachother
    RIFTSPrediction = (DominantFrequencyAnalyteWindow - DominantFrequencyRefWindow)*PhaseToEOTConversion;   %Converting between optical thickness and the arbitrary Morlet Wavelet Phase units using predetermined calibration
    
    R_Difference = AnalyteAngle - RefAngle;      %Phase difference at every wavenumber
    MWP(i) = mean(R_Difference);       %Morlet Wavelet Phase result, average difference in phase                       
    CycleDifference = round((MWP(i) - RIFTSPrediction)/(2*pi));    %Determining if the Morlet Wavelet Phase is more than a phase cycle different from optical thickness given by RIFTS
    MWP(i) = MWP(i) - CycleDifference*2*pi;     %Correct result if Morlet Wavelet Phase has moved into a 
    MWP(i) = (MWP(i))/PhaseToEOTConversion;      %Converting between arbitrary Morlet Wavelet Phase units and optical thickness using predetermined calibration
    
    %%% Add Morlet wavelet phase result of ith spectra to plot
    disp(['Current spectra is ' num2str(AllSpectraFiles(i).name) ' MWP result is ' num2str(MWP(i))]);        %Print filename of ith spectra currently being analysed, and corresponding Morlet wavelet phase result
    plot(MWP, 'Color', [0, 0.4470, 0.7410])
    ylabel('Morlet Wavelet Phase \DeltaEffective Optical Thickness (nm)');
    xlabel('Spectrum Number');
    hold on;
    drawnow;
end

%% Functions

%%% Read .txt spectra files and preprocess spectrum data
function RInterpolated = ReadSpectrum(Filename, Desiredk)

    Spectrum= readmatrix(Filename);     %Load spectrum data
    Lambda =Spectrum(:,1);R = Spectrum(:,2);      %Extract reference wavelength and reflectance for spectrum
    R = R - mean(R);       %Remove the mean from reflectance    
    Fullk = flip(1./Lambda);     %Invert wavelength to obtain k values, and flip vector to get values in ascending order 
    RFlip = flip(R);     %Flip reflectance vector to match up with flipped k-values
    RInterpolated = interp1(Fullk, RFlip, Desiredk);        %Interpolated reflectance at every desired k value
    RInterpolated = RInterpolated - mean(RInterpolated);       %remove mean from Interpolated spectrum

end

%%% Fast Fourier transform on interpolated spectra, and identify the
%%% frequency location and width of the dominant peak
function [FWHM, DominantFrequency] = FastFourierTransform(RInterpolated, n, ReducedFrequencyRange, frequency)

    FFT = fft(RInterpolated, n);     %Carry out FFT of interpolated spectrum
    Power = abs(FFT/n);     %Normalize FFT output
    Power = Power(1:n/2+1);     %Only considering positive frequencies
    Power = Power(ReducedFrequencyRange);        %Only consider frequencies in the range estimated
    [~,peakLoc, FWHM] = findpeaks(Power,'SortStr','descend','WidthReference','halfheight');     %Find center frequency and FWHM of peaks (in order of descending height)
    DominantFrequency = frequency(peakLoc(1));        %Use frequency of dominant peak

end

%%% Filter spectra through convolution with a Morlet wavelet with
%%% parameters defined according to the FFT
function WaveletFilteredR = WaveletTransform(DominantFrequency, Waveletk, FWHM, RInterpolated)

    WaveletExponential = exp(1i*2*pi*DominantFrequency.*Waveletk);     %Complex exponential with dominant frequency 
    WaveletStdev =1/( 2*sqrt(2*log(2))*FWHM(1));      %Standard deviation of gaussian wavelet envelope, converting FFT FWHM to gaussian stdev
    WGaussianEnvelope  = exp((-Waveletk.^2)./(2*WaveletStdev^2));     %Define Gaussian wavelet envelope 
    CMW = WaveletExponential.*WGaussianEnvelope;       %Complex Morlet Wavelet
    WaveletFilteredR = conv(RInterpolated,CMW,'same');      %Spectrum filtered by convolution with the complex Morlet wavelet
    WaveletFilteredR = WaveletFilteredR./(abs(WaveletFilteredR));     %Remove envelope (complex amplitude) of filtered spectrum (not necessary for MWP method)

end