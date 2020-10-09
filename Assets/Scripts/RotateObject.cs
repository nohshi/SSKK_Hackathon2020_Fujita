using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RotateObject : MonoBehaviour
{
    public bool bRotate = true;
    public float speed = 0.5f;

    private Transform currentTransform;

    // Start is called before the first frame update
    void Start()
    {
        currentTransform = this.gameObject.transform;
    }

    // Update is called once per frame
    void Update()
    {
        if (bRotate)
        this.gameObject.transform.Rotate(new Vector3(1, 0, 0), -speed);
    }

    void OnDestroy() {
        this.gameObject.transform.rotation = currentTransform.rotation;
    }
}
