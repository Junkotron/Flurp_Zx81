

#f=[50 100 200 400 800 1600 3200 6400 100000 1000000]

f=[10:20000];
  
w=2*pi*f;
  
R1=1E3;
C1=47E-9;

# Impedance from voltage source
#Ri=1E3;
Ri=0;



F1=1/(2*pi*R1*C1);

# Transferfunction 1
T1 = R1 ./ (Ri + 1./(i*w*C1) + R1);

R2=1E3;
C2=47E-9;

F2=1/(2*pi*R2*C2);

XC2=1./(i*w*C2);

#Impedance into line input
Ro=10E3;
#Ro = 1E9;

XC2parRo = XC2 .* Ro ./ (XC2 + Ro);

# Transferfunction 2
#T2=XC2parRo ./ (XC2parRo/ + R2);
T2=XC2 ./ (XC2 + R2);

Ttot=T1.*T2;

Uline=(3.3/2)*abs(Ttot);

Line_dBm=20*log10(Uline);

