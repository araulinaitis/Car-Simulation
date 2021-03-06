classdef Car < handle
    % THIS IS A STRIPPED-DOWN VERSION OF THE CAR MODEL, FOR VEHICLE DYNAMIC TESTING ONLY
    properties
        m
        l
        w
        state % 0: go straight, 1: change lanes right, -1: change lanes left
        curState
        acc
    end
    
    properties(Access = private)
        maxYAccel = 9.81; % will be used later for braking
        desiredYAccel = 9.81 / 4;
        maxXAccel = 0.981;
        desiredXAccel = .981;
        desiredSpeed
        desiredHeadway
        p
        sys
        kI
        kP
        kD
        uCap
        lastU = [0, 0];
        deltaUCap = [0, 0];
        errSum = [0, 0; 0, 0; 0, 0; 0, 0]
        lastErr = 0
        integralWindow = [0.25; 0; 3; 2.5] % [x, x-dot, y, y-dot]
        targetState = [0; 0; 0; 0]
        controlMask = [1, 0, 0, 1]
        err = [0, 0; 0, 0; 0, 0; 0, 0];
        headwayWindow
    end
    
    methods
        function obj = Car()
            
            % Vehicle State: [x, x-dot, y, y-dot]'
            obj.curState = [0; 0; 0; 35]; % start car at 35 m/s
            
            obj.m = 10 + 10 * rand;
            obj.l = 3 + 3 * rand;
            obj.w = 2 + rand;
            
            obj.state = 0;
            obj.acc = [0, 0];
            
            obj.desiredSpeed = [0, 35];
            obj.desiredHeadway = 2;
            obj.headwayWindow = obj.desiredSpeed(2) * obj.desiredHeadway * 1.01;
            
            xArr = obj.curState(1) + (obj.w / 2) * [1; 1; -1; -1];
            yArr = obj.curState(3) + (obj.l / 2) * [1; -1; -1; 1];
            obj.p = patch(xArr, yArr, 'k');
            
            b = .1; % seems like a good value from testing, can change later
            
            % Car Physical Model
            % http://ctms.engin.umich.edu/CTMS/index.php?example=CruiseControl&section=SystemModeling
            A = [0, 1;
                0, -b / obj.m];
            
            B = [0; 1 / obj.m];
            
            C = [1, 0;
                0, 1];
            
            D = [0; 0];
            
            A = blkdiag(A, A);
            B = blkdiag(B, B);
            C = blkdiag(C, C);
            D = blkdiag(D, D);
            
            obj.sys = ss(A, B, C, D);
            
            obj.kP = [8, 0,...
                32, 8];
            obj.kI = [0, 0,...
                0.5, 0.5];
            obj.kD = [17, 0,...
                0.25, 10];
            
            obj.uCap = [obj.m * obj.desiredXAccel, obj.m * obj.desiredYAccel];
            obj.deltaUCap(1) = 0.981 * obj.m; % https://www.hindawi.com/journals/mpe/2014/478573/
            obj.deltaUCap(2) = 0.18 * 9.81 * obj.m;
            
        end
        
        function doPhysics(obj, dt)
            
            
            err = obj.targetState - obj.curState;
            obj.err = err;
            err = [[err(1); err(2); 0; 0], [0; 0; err(3); err(4)]];
            errDer = (err - obj.lastErr) / dt;
            
            colSeq = [1, 1, 2, 2];
            for i = 1:4
                obj.errSum(i, colSeq(i)) = (obj.errSum(i, colSeq(i)) + err(i, colSeq(i))) * double(abs(err(i, colSeq(i))) < obj.integralWindow(i)); % add to the sum if the error is less than the window value (boolean 1) and reset the sum to 0 if the value is outside the window (boolean 0)
            end
            
            obj.lastErr = err;
            
            u = (obj.controlMask .* obj.kP) * err + (obj.controlMask .* obj.kI) * obj.errSum + (obj.controlMask .* obj.kD) * errDer; % u will be 1x2 [ux, uy]
            
            % lazy low-pass filter u
            deltaU = u - obj.lastU;
            for i = 1:2
                if abs(deltaU(i)) > obj.deltaUCap(i)
                    u(i) = obj.lastU(i) + sign(deltaU(i)) * obj.deltaUCap(i);
                end
                if u(i) > obj.uCap(i)
                    u(i) = obj.uCap(i);
                end
            end
            
            obj.lastU = u;
            
            numSteps = 20;
            t = linspace(0, dt, numSteps)';
            y = lsim(obj.sys, u .* ones(numSteps, 1), t, obj.curState');
            
            lastYPos = obj.curState(3);
            lastXPos = obj.curState(1);
            lastXVel = obj.curState(2);
            lastYVel = obj.curState(4);
            obj.curState = y(end, :)';
            obj.acc(1) = (obj.curState(2) - lastXVel) / dt;
            obj.acc(2) = (obj.curState(4) - lastYVel) / dt;
            obj.p.Vertices = obj.p.Vertices + [obj.curState(1) - lastXPos, obj.curState(3) - lastYPos];
        end
        
        function update(obj, dt)
            
            % hard-code changes for testing
            % obj.targetState(4) = obj.desiredSpeed(2);
            % obj.targetState(1) = 3.7;
            
            global t
            t = t + dt;
            
            dummySpeed = 30;
            dummyCarBack = dummySpeed * t + 100; % start 100m ahead, 30 m/s speed
            gap = dummyCarBack - obj.curState(3) + (obj.l / 2);
            
            if gap < obj.headwayWindow
                % use position of car in front and current speed and desired headway to
                % determine desired y-pos
                headwayDist = obj.desiredHeadway * obj.curState(4);
                obj.targetState(3) = obj.curState(3) + gap - headwayDist - (obj.l / 2);
                obj.targetState(4) = dummySpeed;
%                 obj.controlMask(4) = 0;
                obj.controlMask(3) = 1;
            else
                obj.targetState(3) = obj.curState(3);
                obj.targetState(4) = obj.desiredSpeed(2);
                obj.controlMask(3) = 0;
                obj.controlMask(4) = 1;
            end
            
            
            obj.doPhysics(dt);
        end
        
        function out = getError(obj)
            out = obj.err;
        end
        
        function out = getDesiredSpeed(obj)
            out = obj.desiredSpeed;
        end
        
        function out = getYVel(obj)
            out = obj.curState(4);
        end
        
        function out = getYPos(obj)
            out = obj.curState(3);
        end
        
        function out = getXVel(obj)
            out = obj.curState(2);
        end
        
        function out = getXPos(obj)
            out = obj.curState(1);
        end
        
        function out = getCurState(obj)
            out = obj.curState;
        end
        
        function out = getTargetState(obj)
            out = obj.targetState;
        end
        
        function kill(obj)
            delete(obj.p);
        end
        
    end
end





















