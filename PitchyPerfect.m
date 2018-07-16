function [ output_args ] = PitchyPerfect( input_args )
%PITCHYPERFECT Summary of this function goes here
%   Detailed explanation goes here

firebaseURL = 'https://scorching-inferno-3389.firebaseio.com/Frequency.json';

readURL = 'https://scorching-inferno-3389.firebaseio.com/Target.json';

options = weboptions('MediaType','json');

%Load in HRTF
load(deblank(sprintf('%s', 'Kyla_HRTF.mat')));

%set variables
base_frequency = 440;
selected_frequency = 440;
steps_from_center = 0;
freq_two_below = base_frequency*(2^(1/12))^(steps_from_center-2);
freq_two_above = base_frequency*(2^(1/12))^(steps_from_center+2);
freq_diff = freq_two_above - freq_two_below;
samplerate = 8000;
FrameSize = 1024;
elevation = 0;

%Create Audio Recorder and Player
AR = dsp.AudioRecorder('SampleRate',samplerate,...
                       'SamplesPerFrame',FrameSize);
AP = dsp.AudioPlayer('SampleRate',samplerate,...
    'OutputNumUnderrunSamples',true);
    
Target = webread(readURL, options);
steps_from_center = cell2mat(struct2cell(Target));
display(Target);
selected_frequency = base_frequency*(2^(1/12))^(steps_from_center);
    
freq_two_below = base_frequency*(2^(1/12))^(steps_from_center-2);
freq_two_above = base_frequency*(2^(1/12))^(steps_from_center+2);
freq_diff = freq_two_above - freq_two_below;


tic
Tstop = 60;
while toc < Tstop
   
    
    
    audioIn = step(AR);
    [maxvalue,indexMax] = max(abs(fft(audioIn)));
    freq = indexMax*samplerate/size(audioIn)
    if freq>300
    
    azimuth = (freq-selected_frequency)/freq_diff;
    pos = 0 + (800/freq_diff)*(freq-freq_two_below)
    azimuth = floor(azimuth*10);
    azimuth = azimuth/10;
    azimuth=azimuth*100;
    if(azimuth>90)
        azimuth = 90;
    elseif(azimuth<-90)
        azimuth = -90;
    end
    
    %display(azimuth);
    
    
    
    
    iAz = find(Theta == azimuth);
    iEl = find(Phi == elevation);
    iLoc = intersect(iAz, iEl);
    delay = delay_based_on_HRTF(iLoc); 


    %get the common transfer function and the directional transfer function
    %and inverse fft to get the impulse response
    %won't need this for MARL or CIPIC - skip straight to next section

    %create the impulse response for the left ear from frequency response
    %this step is not necessary if the HRTF database stores the Impulse
    %repsonse
    x = real(ifft(10.^((LDTFAmp(:, iLoc)+LCTF)/20)));
    %get real cepstrum of the real sequence
    [y, tmp] = rceps(x);
    lft = tmp(1:min(length(tmp), 256)); 

    %create the impulse response for the right ear from frequency response
    %this step is not necessary if the HRTF database stores the Impulse
    %repsonse
    x = real(ifft(10.^((RDTFAmp(:, iLoc)+RCTF)/20)));
    %get real cepstrum of the real sequence
    [y, tmp] = rceps(x);
    rgt = tmp(1:min(length(tmp), 256)); 

    %add delay
    %this step is not necessary if database includes the delay as part of
    %the impulse response
    if delay <= 0 
        lft = [lft' zeros(size(1:abs(delay)))];
        rgt = [zeros(size(1:abs(delay))) rgt'];
    else
        lft = [zeros(size(1:abs(delay))) lft'];
        rgt = [rgt' zeros(size(1:abs(delay)))];
    end

    %make sure left and right ear vectors are the same size
    npts = max(length(lft), length(rgt));
    lft = [lft zeros(size(1:320-npts))];
    rgt = [rgt zeros(size(1:320-npts))];
    
    sig = step(AR);
    sig = sig(:,1); 
    
    
    %convolve with left and right impulse responses
    wav_left = conv(lft', sig) ;
    wav_right = conv(rgt', sig);

    
    %create sound to play 
    soundToPlay(:,1) = wav_left;
    soundToPlay(:,2) = wav_right;
    
    %play frame of data
    sound(soundToPlay,samplerate);
    %step(AP,soundToPlay);
    data = struct('Frequency',freq,'Target',selected_frequency);
    webwrite(firebaseURL,data,options);
    
    end
end

    

end

