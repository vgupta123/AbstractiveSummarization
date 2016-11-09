require 'rnn'
require 'optim'
---------------------------------
print('Importing w2vutils')
wv=require 'w2vutils'
print('Done importing w2vutils')

require 'cutorch'
require 'cunn'

cutorch.setDevice(1)
--torch.setdefaulttensortype('torch.CudaTensor')
print('Running with CUDA on GPU')
----------------------------------

file_txt=io.open('text_words.csv','r')
file_smy=io.open('text_summary.csv','r')

batch_count=0
--batchSize = 50
--rho = 10000
rho = 10
inputSize = 300
--lstmOutputSize1 = 10
--lstmLayerSize1 =100
--hiddenSize1 = lstmOutputSize1*lstmLayerSize1
hiddenSize1=1000 
hiddenSize2 =1000   
hiddenSize3 = 100
outputSize = 300 

print('Begin')

--*************************************************************
print('Building the Model')
model = nn.Sequential()

LSTM_Layer_1=nil
print('added lstm layer 1')
--model:add(nn.Sequencer(nn.Linear(300,hiddenSize1)))
--model:add(nn.Sequencer(nn.FastLSTM(hiddenSize1,hiddenSize2,rho)))
--model:add(nn.Sequencer(nn.Tanh()))
--model:add(nn.Sequencer(nn.FastLSTM(hiddenSize2, hiddenSize3, rho)))
--model:add(nn.Sequencer(nn.Tanh()))
--model:add(nn.Sequencer(nn.Linear(hiddenSize3,300)))
--model:add(nn.Sequencer(nn.Tanh()))
--criterion = nn.SequencerCriterion(nn.MSECriterion())


model:add(nn.Linear(300,hiddenSize1))
model:add(nn.FastLSTM(hiddenSize1,hiddenSize2,rho))

--model:add(nn.Tanh())

model:add(nn.FastLSTM(hiddenSize2, hiddenSize3, rho))

--model:add(nn.Tanh())

model:add(nn.Linear(hiddenSize3,300))

--model:add(nn.Tanh())

model:remember('both')
model=model
criterion = nn.MSECriterion()
criterion=criterion
print('Done Building the model')
--*************************************************************

function nextBatch()
    local inputs, targets = {}, {}
  --  print('	    ----------------------------------------------')
    line = file_txt:read()
    while line ~= "" and line~=nil do 
        --print(line)
  	    tmp=wv:word2vec(line)
        tmp2=torch.DoubleTensor(tmp:size()):copy(tmp)
	
--	for i=1,lstmLayerSize1-1 do
--		tmp2=torch.cat(tmp2,tmp2)	
--	end
        table.insert(inputs,tmp2)
        tmp=nil
        tmp2=nil 
        line=file_txt:read()
    end

    --table.insert(inputs, (torch.DoubleTensor(300):zero())) 
   
    line = file_smy:read()
    
    while line ~= "" and line~= nil  do
        tmp=wv:word2vec(line)
        tmp2=torch.DoubleTensor(tmp:size()):copy(tmp)
        --print(line)
        table.insert(targets,tmp2)
        tmp1=nil
        tmp2=nil 
        line = file_smy:read()
    end 
 
    --table.insert(inputs,(torch.DoubleTensor(300):zero()))
    ------------------------------------------------
    return inputs, targets
end
--*************************************************************


--*************************************************************
feval = function(x_new)
      
    if x ~= x_new then
        x:copy(x_new)
    end
  
    local inputs, targets = nextBatch()

    dl_dx:zero()

    for i=1,#inputs do 
        prediction = model:forward(inputs[i])
    end

    zero_table_vector=torch.Tensor(300):zero()
    prediction = model:forward(zero_table_vector)
    
    model:backward(zero_table_vector, criterion:backward(prediction, targets[1]))

  
    local loss_x=0
    loss_x = criterion:forward(prediction,targets[1])

    for i=2,#targets do  
        prediction=model:forward(prediction)
        loss_x = loss_x+criterion:forward(prediction,targets[i])
        model:backward(prediction, criterion:backward(prediction,targets[i]))
        --print(wv:distance(prediction:float(),5))
    end 


    prediction = model:forward(zero_table_vector)
    model:backward(zero_table_vector, criterion:backward(prediction, zero_table_vector))
    model:forget()
    batch_count=batch_count+1
    torch.save('predicted_summary_vectors',predicted_summary)

    model:forget()
    return loss_x, dl_dx
end
--*************************************************************



-- get weights and gradient of loss wrt weights from the model
print('Getting Parameters')
x, dl_dx = model:getParameters()
print('Done')

print('Getting sgd_arams')
sgd_params = {
    learningRate = 5e-1,--changed from 1e-2
    learningRateDecay = 1e-4,
    weightDecay = 0,
    momentum = 0.5
}
print('Done')

print('Training')
for j=1,10 do
	print("EPOCH: "..j)
	------------------------------------------
	file_txt = io.open('text_words.csv','r')
	file_smy = io.open('summary_words.csv','r')
	------------------------------------------
	for i = 1, 50000 do
	    -- train a mini_batch of batchSize in parallel
	    _, fs = optim.sgd(feval,x, sgd_params)

		print('error for iteration ' .. sgd_params.evalCounter  .. ' is ' .. fs[1] / rho)
	    if sgd_params.evalCounter % 100 == 0 then
		torch.save('model_tmp', model)
		print('error for iteration ' .. sgd_params.evalCounter  .. ' is ' .. fs[1] / rho)
	    end
	end
end
print('Done')
