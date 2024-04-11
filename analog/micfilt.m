

# filter with some resistors and caps
# impedances form a voltage divider

# Having 1Mohm in series means we can neglect the ULA output imp

# a few checkpoints against the Proto simulations

#f=[50 100 200 400 800 1600 3200 6400 100000 1000000]

# Zoom on lower freq
#f=[10:1000];

f=[10:20000];

w=2*pi*f;

R1=1E6;
  
C1=47E-12;
  
Z1 = R1 - i./(w*C1);

R2=1E3;
  
C2=47E-9;

Vula = 2.5;

Rmic = 600;
  
# Z2 = R2 // C2
XC2 = 1 ./ (i * w .* C2);
Z2 = R2 .* XC2 ./ (R2 + XC2);

# Umic = Rmic // Z2 + (Rmic // Z2 + Z1)
RmicparZ2 = Rmic*Z2./(Rmic + Z2);
Umic = Vula * RmicparZ2 ./ (Z1 + RmicparZ2);


Umicabs=abs(Umic);

# Those are dBm's ?
Mic_dBm = 20*log10(Umicabs);
