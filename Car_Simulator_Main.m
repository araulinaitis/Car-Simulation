clear all; clc; close all;

figure(1)
axis equal
numCars = 1;
global t
t = 0;

testCar = Car;

% for i = 1:numCars
%     highway.introduce();
% end
dt = .1;
xVelArr = testCar.getXVel;
yVelArr = testCar.getYVel;
xArr = testCar.getXPos;
yArr = testCar.getYPos;
yAccArr = testCar.acc(2);
xAccArr = testCar.acc(1);
tArr = 0;

while 1
    %     figure(1)
    testCar.update(dt);
    drawnow
    
targetState = testCar.getTargetState;
desiredSpeed = targetState(4);
desiredXPos = targetState(1);
carState = testCar.getCurState;
carError = testCar.getError;

    xArr = [xArr, carState(1)];
    yArr = [yArr, carError(3)];
%     yArr = [yArr, carState(3)];
    xVelArr = [xVelArr, carState(2)];
    yVelArr = [yVelArr, carState(4)];
    xAccArr = [xAccArr, testCar.acc(1)];
    yAccArr = [yAccArr, testCar.acc(2)];
    tArr = [tArr, tArr(end) + dt];
    
    figure(2)
    clf
    plot(tArr, yVelArr);
    hold on
    plot(tArr, yArr);
    plot(tArr, desiredSpeed * ones(1, length(tArr)));
    plot(tArr, yAccArr);
    legend({'Y-Speed', 'Y-Error', 'Desired Speed', 'Y-Accel'});
    xlabel('time (s)')
    ylabel('m (y) m/s (v) m/s^2 (a)')
    
%     figure(3)
%     clf
%     plot(tArr, xArr);
%     hold on
%     plot(tArr, desiredXPos * ones(1, length(tArr)));
%     plot(tArr, xVelArr);
%     plot(tArr, xAccArr);
%         legend({'X-Position', 'Desired Position', 'X-Velocity', 'X-Acceleration'});
%         xlabel('time (s)')
%         ylabel('m (x), m/s (v), m/s^2 (a)')
    
end