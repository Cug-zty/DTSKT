function run(Algo, Prob)
Prob.N = 200;
% Initialization
population = Initialization(Algo, Prob, Individual_ED);
Elit_N = round(Algo.A * Prob.N);
for t = 1:Prob.T
    [~, rank{t}] = sortrows([population{t}.CVs, population{t}.Objs], [1, 2]);
    a = 0; b = 0;
    for i = 1: Elit_N
        a = a + (log(Elit_N+1)-log(i)).* population{t}(rank{t}(i)).Dec;
        b = b + log(Elit_N+1)-log(i);
    end
    M{t} =  a./b;
    M_old{t} = mean(population{t}.Decs);
    QQ = population{t}(rank{t}(1:Elit_N)).Decs;
    QQ = QQ - repmat(M{t},Elit_N,1);
    WW = zeros(1,Prob.D(t));
    for i = 1 : Elit_N
        WW = WW + QQ(i,:).*QQ(i,:);
    end
    WW = WW./Elit_N; WW = WW.^(1/2);
    S{t} = WW;
    path{t} = population{t}(rank{t}(randi(3))).Dec-M_old{t};
    for i = 1 : Prob.N
        population{t}(i).IfTrans = 0;
    end
end
%         MaxGenerations = (Prob.maxFE/Prob.N)/Prob.T; % Define the total number of generations
%         msim_history_task1 = zeros(1, MaxGenerations);
while Algo.notTerminated(Prob, population)
    % Calculate COS
    CO = zeros(Prob.T);
    for t = 1:Prob.T - 1
        for k = t + 1:Prob.T
            CO(t, k) = exp(dot(path{t},path{k})/(norm(path{t})*norm(path{k})))^2;
            CO(k, t) = CO(t, k);
        end
    end

    for t = 1:Prob.T
        for i = 1 : Prob.N
            population{t}(i).IfTrans = 0;
        end
        OO = population{t}(1);
        OO.Dec = M{t}; OO  = Algo.Evaluation(OO , Prob, t);
        flag = 0;
        idx = [];
        trans_id = [];
        mDec{t} = mean(population{t}.Decs);

        [max_co,k] = max(CO(t,:));
        msr = max_co/(sum(CO(t,:)));
        %                 msim_history_task1(Algo.Gen) = msr;
        %                 disp(msr)
        if msr > (2/Prob.T)
            PATH = path{k};
            POPM = population{k}(rank{k}(1:Elit_N)).Decs;
            POPM = [(POPM-repmat(M_old{k},size(POPM,1),1)+repmat(mDec{t},size(POPM,1),1));population{t}(rank{t}(1:Elit_N)).Decs];
            POPM = POPM - repmat(M{t},size(POPM,1),1);
            WW = zeros(1,Prob.D(t));
            for i = 1 : size(POPM,1)
                WW = WW + POPM(i,:).*POPM(i,:);
            end
            WW = WW./size(POPM,1); WW = WW.^(1/2);
            S1 = WW;
        else
            PATH = zeros(1,Prob.D(t));
            [~,CO2] = sort(CO(k,:),'descend');
            TOP_idx = CO2(1:Algo.TOPN);
            if ismember(t,TOP_idx)
                TOP_idx(TOP_idx==t)=[];
            end
            TOP_idx = [TOP_idx,k];
            w = [];
            for i = 1:length(TOP_idx)
                w(i) = CO(t,TOP_idx(i))/(sum(CO(t,:)));
            end
            sum_w = sum(w);
            w = w./sum_w;
            for i = 1:length(w)
                PATH = PATH + w(i).* path{TOP_idx(i)};
            end
            Deta_S = {};
            for i = 1: length(TOP_idx)
                kk = TOP_idx(i);
                POPM = population{kk}(rank{kk}(1:Elit_N)).Decs;
                POPM = [(POPM-repmat(M_old{kk},size(POPM,1),1)+repmat(mDec{t},size(POPM,1),1));population{t}(rank{t}(1:Elit_N)).Decs];
                POPM = POPM - repmat(M{t},size(POPM,1),1);
                WW = zeros(1,Prob.D(t));
                for j = 1 : size(POPM,1)
                    WW = WW + POPM(j,:).*POPM(j,:);
                end
                WW = WW./size(POPM,1); WW = WW.^(1/2);
                S2 = WW;
                Deta_S{i} = w(i).* S2;
            end
            DDD = zeros(1,Prob.D(t));
            for i = 1: length(TOP_idx)
                DDD = DDD + Deta_S{i};
            end
            S1 = DDD;
        end
        for i = 1: (Prob.N-2)
            offspring(i) = population{t}(i);
            if flag ==0
                if rand()<Algo.RMP
                    %exploring
                    if Algo.FE < Algo.Beta * Prob.maxFE
                        offspring(i).Dec = normrnd(M{t}+rand().*PATH,S{t});
                        %exploiting
                    else
                        offspring(i).Dec = normrnd(M{t},S1);
                    end
                    trans_id = [trans_id, i];
                else
                    offspring(i).Dec = normrnd(M{t},S{t});
                    offspring(i).IfTrans =0;
                end
                offspring(i).Dec(offspring(i).Dec > 1) = 1;
                offspring(i).Dec(offspring(i).Dec < 0) = 0;
                offspring(i)  = Algo.Evaluation(offspring(i) , Prob, t);
                if offspring(i).Obj>OO.Obj
                    flag = 1;
                end
                idx = [idx,i];
            else
                offspring(i).Dec = 2.*M{t} -  offspring(i-1).Dec;
                flag = 0;
                offspring(i).Dec(offspring(i).Dec > 1) = 1;
                offspring(i).Dec(offspring(i).Dec < 0) = 0;
                offspring(i)  = Algo.Evaluation(offspring(i) , Prob, t);
                offspring(i).IfTrans =0;
            end
        end
        offspring(Prob.N - 1) = population{t}(rank{t}(1));
        offspring(Prob.N) = OO;
        %                     POPM = offspring;
        %                     POPM(idx) = [];
        %                     POPM = Algo.Evaluation(POPM  , Prob, t);
        population{t} = offspring;
        for i = 1:length(trans_id)
            population{t}(i).IfTrans = 1;
        end
        % Selection
        [~, rank{t}] = sortrows([population{t}.CVs, population{t}.Objs], [1, 2]);
        M_O = M{t};
        a=0;b=0;
        for i = 1: Elit_N
            a = a + (log(Elit_N+1)-log(i)).* population{t}(rank{t}(i)).Dec;
            b = b + log(Elit_N+1)-log(i);
        end
        M{t} =  a./b;
        D_M = M{t} - M_O;
        O1 = population{t}(1);     O2 = population{t}(1); O3 = population{t}(1); O4 = population{t}(1);
        O1.Dec = M{t} + 2.*D_M;    O2.Dec = M{t};         O3.Dec = M_O;        O4.Dec = M{t}-0.5.*D_M;
        O = [O1,O2,O3,O4];
        O = Algo.Evaluation(O , Prob, t);
        if O(1).Obj < O(2).Obj && O(2).Obj < O(3).Obj
            M{t} = O(1).Dec;
        elseif O(2).Obj > max(O(3).Obj, O(4).Obj)
            M{t} = O(4).Dec;
        else
            M{t} = M{t};
        end
        QQ = population{t}(rank{t}(1:Elit_N)).Decs;
        QQ = QQ - repmat(M{t},Elit_N,1);
        WW = zeros(1,Prob.D(t));
        for i = 1 : Elit_N
            WW = WW + QQ(i,:).*QQ(i,:);
        end
        WW = WW./Elit_N; WW = WW.^(1/2);
        S{t} = WW;
        path{t} = population{t}(rank{t}(randi(3))).Dec-M_old{t};
        M_old{t} = mean(population{t}.Decs);
    end
end
end