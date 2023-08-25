%Skye Mceowen
%ACL 2018-2019 - April 25, 2019
%Rover Kinematic Model - ODE 45 simulation
%Continuous control

clear all, close all, clc

%setting up variables (change things here)
    delta = 0.01;%0.001; %time step %DONT CHANGE THIS
    tf = 10; %CHANGE THIS IF YOU NEED MORE STEPS
    times = 0:delta:tf; 
    steps = length(times) %number of time steps
    times = delta*(1:1:steps)'; %vector of times you're simulating
    IC = zeros(6,1); %initial condition
    state(:,1) = IC;
    s = tf('s'); %ignore
    
    %controller tuning:
    Kp = 25; Ki = 4; Kd = 2.5; %CAN CHANGE GAINS IF YOU WANT
    tau_d = 1; 
    
    %trajectory generator
    ref_handle = @r; 

%setting up actuator state space model
    f_A = 1; %bandwidth of the actuator in Hz
    A = tf([0 2*pi*f_A],[1 2*pi*f_A]); %actuator filter transfer function
    A_ss = ss(A); %state space model of actuator transfer function

%setting up controller state space model
    Cx = Kp + Ki/s + Kd*s*(1/tau_d)/(s+(1/tau_d)); %C(s) design (TF), x
    Cy = Kp + Ki/s + Kd*s*(1/tau_d)/(s+(1/tau_d)); % " y
    Ct = Kp + Ki/s + Kd*s*(1/tau_d)/(s+(1/tau_d)); % " theta

    Cx_ss = c2d(ss(Cx),delta); %C(s) design (State Space), x
    Cy_ss = c2d(ss(Cy),delta); % " y
    Ct_ss = c2d(ss(Ct),delta); % " theta
    
    %Initializing controller
    x_Cx = [0; 0]; x_Cy = [0; 0]; x_Ct = [0; 0];
    ctrl(:,100) = [0; 0; 0];
    
%setting up plant state space model
    %might not need?
    
%Determine indices for plotting
    n_A = length(A_ss.A);   %length of actuator state
    n_P = 3;               %plant state vector (x,y,theta)

    i_x_P = (1:n_P);    %plant state indices
    i_x_A1 = (1:n_A)+i_x_P(end);   %actuator 1 state indices
    i_x_A2 = (1:n_A)+i_x_A1(end);   %actuator 2 state indices
    i_x_A3 = (1:n_A)+i_x_A2(end);   %actuator 3 state indices

    
%%{
%calling continuous derivative function in ODE45
hunCount = 1;
for k = 1:steps
    %print out every 100th k
    if mod(k,(steps-1)/10) == 0
        k
    end
    
    %determine reference signal at current time
    %ADD REFERENCE HERE
    %NOTE: state(i_x_P,k) is your current x,y,theta
    %state contains more info than just your x,y,theta
        %so make sure you use the i_x_P index in the row to select x,y,theta
    ref(:,k) = ref_handle(times(k)); %CHANGE WHERE THIS IS COMING FROM
        x_ref(k) = ref(1,k);    %for plotting later
        y_ref(k) = ref(2,k);    % "
        theta_ref(k) = ref(3,k);%"
    
    %determine control input and output evolution
    error(:,k) = ref(:,k) - state(i_x_P,k); %calculate error
    x_Cx(:,k+1) = Cx_ss.A*x_Cx(:,k) + Cx_ss.B*error(1,k); %controller state for x
    x_Cy(:,k+1) = Cy_ss.A*x_Cy(:,k) + Cy_ss.B*error(2,k); % " for y
    x_Ct(:,k+1) = Ct_ss.A*x_Ct(:,k) + Ct_ss.B*error(3,k); % " for theta
    
    y_Cx(:,k) = Cx_ss.C*x_Cx(:,k) + Cx_ss.D*error(1,k); %controller command for x
    y_Cy(:,k) = Cy_ss.C*x_Cy(:,k) + Cy_ss.D*error(2,k); % " for y
    y_Ct(:,k) = Ct_ss.C*x_Ct(:,k) + Ct_ss.D*error(3,k); % " for theta
    
    ctrl(:,k) = [y_Cx(k); y_Cy(k); y_Ct(k)];
    
    %determine system state evolutaiton
    if k < steps
        [~,temp] = ode45(@(t,x) derivs_d(t,x,ctrl(:,k),A_ss),[0 delta],state(:,k));
        temp = temp';
        state(:,k+1) = temp(:,end); %next x,y,theta
        clear temp
    end
end

%Separating out vectors for plotting
    x_P = state(i_x_P,:); x = x_P(1,:); y = x_P(2,:); theta = x_P(3,:);

    x_A1 = state(i_x_A1,:);   %extracting actuator 1 state vector
    x_A2 = state(i_x_A2,:);   %extracting actuator 2 state vector
    x_A3 = state(i_x_A3,:);   %extracting actuator 3 state vector

%plotting
    figure
    plot(times,x_P-ref)
    title('Error vs. Time')
    xlabel('Time [s]')
    ylabel('Error')
    legend('e_x','e_y','e_{\theta}')
    ylim([-5 5])
    xlim([0 10])

    figure
    plot(x,y,x_ref,y_ref)
    title('x vs. y')
    xlabel('x [m]')
    ylabel('y [m]')
    legend('Rover Trj','Reference Signal')
    
    figure
    plot(times,x,times,y,times,x_ref,times,y_ref)
    title('(x,y) Position vs. Time')
    xlabel('Time [s]')
    ylabel('x,y [m]')
    legend('Rover x Trj','Rover y Trj','x Reference Signal','y Reference Signal')
    xlim([0 10])

    figure
    plot(times,theta,times,theta_ref)
    title('Theta vs. Time')
    xlabel('Time [s]')
    ylabel('Theta [rad]')
    legend('Rover Trj','Reference Signal')
    ylim([-5 5])
    xlim([0 10])
    

    figure
    plot(times,ctrl)
    title('Control Input vs. Time')
    xlabel('Time [s]')
    ylabel('Control Input [m/s] or [rad/s]')
    legend('x','y','theta')
    xlim([0 10])
    
    figure
    plot(times,x_A1,times,x_A2,times,x_A3)
    title('Actuator Response vs. Time')
    xlabel('Time [s]')
    ylabel('Actuator Response')
    legend('Actuator 1','Actuator 2','Actuator 3')
    xlim([0 10])
    %}