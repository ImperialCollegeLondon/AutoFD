function [n, r]= bxct(EdgeImage,minboxsz,maxboxsz)

dimxy = size(EdgeImage);
% check and make image dimension sizes even for symetric padding on both sides 
if mod(dimxy(1),2), EdgeImage(dimxy(1)+1,:)=0; dimxy(1)=dimxy(1)+1;end
if mod(dimxy(2),2), EdgeImage(:,dimxy(2)+1,:)=0; dimxy(2)=dimxy(2)+1;end

if dimxy(1) > dimxy(2)
  padWidth = dimxy(1) - dimxy(2);
  padHeight = 0;
else
  padHeight = dimxy(2) - dimxy(1);
  padWidth = 0;
end

% flipping needs to be done before padding
padI1 = padarray(EdgeImage, [padHeight, padWidth], 'pre');
[nBoxA1, boxSize] = initGrid(padI1, minboxsz, maxboxsz);
padI2 = padarray(flip(EdgeImage, 1), [padHeight, padWidth], 'pre');
[nBoxB1, boxSize] = initGrid(padI2, minboxsz, maxboxsz);
padI3 = padarray(flip(EdgeImage, 2), [padHeight, padWidth], 'pre');
[nBoxC1, boxSize] = initGrid(padI3, minboxsz, maxboxsz);
padI4 = padarray(flip(flip(EdgeImage, 1), 2), [padHeight, padWidth], 'pre');
[nBoxD1, boxSize] = initGrid(padI4, minboxsz, maxboxsz);
%figure(1), imshow(horzcat(padI1,padI2,padI3,padI4))

% also do padding on the other side
padI1 = padarray(EdgeImage, [padHeight, padWidth], 'post');
[nBoxA2, boxSize] = initGrid(padI1, minboxsz, maxboxsz);
padI2 = padarray(flip(EdgeImage, 1), [padHeight, padWidth], 'post');
[nBoxB2, boxSize] = initGrid(padI2, minboxsz, maxboxsz);
padI3 = padarray(flip(EdgeImage, 2), [padHeight, padWidth], 'post');
[nBoxC2, boxSize] = initGrid(padI3, minboxsz, maxboxsz);
padI4 = padarray(flip(flip(EdgeImage, 1), 2), [padHeight, padWidth], 'post');
[nBoxD2, boxSize] = initGrid(padI4, minboxsz, maxboxsz);
%figure(2), imshow(horzcat(padI1,padI2,padI3,padI4))

% also do padding on both sides
padI1 = padarray(EdgeImage, [padHeight, padWidth]/2, 'both');
[nBoxA3, boxSize] = initGrid(padI1, minboxsz, maxboxsz);
padI2 = padarray(flip(EdgeImage, 1), [padHeight, padWidth]/2, 'both');
[nBoxB3, boxSize] = initGrid(padI2, minboxsz, maxboxsz);
padI3 = padarray(flip(EdgeImage, 2), [padHeight, padWidth]/2, 'both');
[nBoxC3, boxSize] = initGrid(padI3, minboxsz, maxboxsz);
padI4 = padarray(flip(flip(EdgeImage, 1), 2), [padHeight, padWidth]/2, 'both');
[nBoxD3, boxSize] = initGrid(padI4, minboxsz, maxboxsz);
%figure(3), imshow(horzcat(padI1,padI2,padI3,padI4))

% take minimum of counts to ensure maximal efficient covering
n = min([nBoxA1; nBoxB1; nBoxC1; nBoxD1; nBoxA2; nBoxB2; nBoxC2; nBoxD2; nBoxA3; nBoxB3; nBoxC3; nBoxD3]);
r = boxSize;

    function [nBox, boxSize] = initGrid(Image, minboxsz, maxboxsz)
        
        % restrict max. box size to 25% of smallest image dimension
        % this avoids the sampling errors at larger box sizes
        startBoxSize = maxboxsz;
        curBoxSize   = startBoxSize;
        ldim = size(Image,1);
        % restrict min. box size to 2 pixel
        % should be higher, but we could not analyse small ventricles then  
        boxSize = [minboxsz:startBoxSize];
        
        nBox    = zeros(1, numel(boxSize));
                
        for sizeCount = 1:numel(boxSize)
            curBoxSize = boxSize(sizeCount);
            
            for macroY = 1:ceil(ldim/curBoxSize)
                for macroX = 1:ceil(ldim/curBoxSize)
                    boxYinit = (macroY-1)*curBoxSize+1;
                    boxXinit = (macroX-1)*curBoxSize+1;
                    boxYend = min(macroY*curBoxSize,ldim);
                    boxXend = min(macroX*curBoxSize,ldim);
                    
                    % check if there is any pixel of the countour in the box 
                    boxFound = false;
                    for curY = boxYinit:boxYend
                        for curX = boxXinit:boxXend
                            if Image(curY,curX)
                                boxFound = true;
                                nBox(sizeCount) = nBox(sizeCount) + 1;
                                break;
                            end
                        end
                        
                        if boxFound == true
                            break;
                        end
                    end                    
                                      
                end
            end
        end    
    end

end