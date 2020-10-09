
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

//曲面方向を計算してテクスチャに書き込むパス

public class ComputeCurvDirPass : ScriptableRenderPass
{
    private Material sampleMaterial;
    private RenderTargetIdentifier currentTarget;
    private RenderTargetHandle rtAttachmentHandle;

    private string PassName => "ComputeCurvDir";
    public string TextureName => "_ComputeCurvDirTexture";

    //https://qiita.com/ruccho_vector/items/10e6227ee3b0c1605176
    //一時的なレンダーターゲット（パスの入出力が同一の場合、いちど中間バッファを挟んでBlitする必要があるため）
    RenderTargetHandle m_TemporaryColorTexture;

    public ComputeCurvDirPass()
    {
        Shader sampleShader = Shader.Find("Hidden/Custom/ComputeCurvDir");
        if (sampleShader != null) sampleMaterial = new Material(sampleShader);
    }

    public void Setup(RenderTargetIdentifier source, RenderTargetHandle destination)
    {
        this.currentTarget = source;
        this.rtAttachmentHandle = destination;
    }

    // This method is called before executing the render pass.
    // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
    // When empty this render pass will render to the active camera render target.
    // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
    // The render pipeline will ensure target setup and clearing happens in an performance manner.
    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        cmd.GetTemporaryRT(rtAttachmentHandle.id, cameraTextureDescriptor, FilterMode.Point);
        ConfigureTarget(rtAttachmentHandle.id);
        ConfigureClear(ClearFlag.All, Color.black);
    }

    // Here you can implement the rendering logic.
    // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
    // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
    // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        //レンダリング情報（画面サイズなど）。一時バッファの作成に使用。
        RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;
        opaqueDesc.depthBufferBits = 0;

        var cmd = CommandBufferPool.Get(PassName);
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();

        //int temp = Shader.PropertyToID("_CameraNormalTexture");
        int w = renderingData.cameraData.camera.scaledPixelWidth;
        int h = renderingData.cameraData.camera.scaledPixelHeight;
        cmd.GetTemporaryRT(m_TemporaryColorTexture.id, w, h, 0, FilterMode.Point, RenderTextureFormat.ARGB32);
        cmd.Blit(currentTarget, m_TemporaryColorTexture.Identifier());
        
        cmd.Blit(m_TemporaryColorTexture.id, rtAttachmentHandle.id, sampleMaterial);
        
        cmd.SetGlobalTexture(TextureName, rtAttachmentHandle.id);

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    /// Cleanup any allocated resources that were created during the execution of this render pass.
    public override void FrameCleanup(CommandBuffer cmd)
    {
        if (rtAttachmentHandle != RenderTargetHandle.CameraTarget)
        {
            cmd.ReleaseTemporaryRT(rtAttachmentHandle.id);
            rtAttachmentHandle = RenderTargetHandle.CameraTarget;
        }
    }
};
